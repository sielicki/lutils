/-
Shared plumbing for lutils applets: exit codes, error reporting in the
`prog: path: reason` style, stdin/file reading, and small parsing helpers.

Every applet has the shape `prog → args → IO UInt32`, where the `UInt32` is
the process exit code. `Main.lean` dispatches either on `argv[0]` (when the
multicall binary is invoked through a symlink such as `cat`) or on the first
argument (`lutils cat ...`).
-/

namespace Lutils

/-- A coreutils-style applet: program name, arguments, exit code. -/
abbrev Applet := String → List String → IO UInt32

/-- lutils version, printed for `--version`. -/
def version : String := "0.1.0"

def exitOk : UInt32 := 0
def exitFail : UInt32 := 1
def exitUsage : UInt32 := 2

/-- Print `prog: msg` to stderr. -/
def reportError (prog msg : String) : IO Unit :=
  IO.eprintln s!"{prog}: {msg}"

/-- Human-readable reason for an `IO.Error`, close to `strerror` wording. -/
def describeError : IO.Error → String
  | .noFileOrDirectory _ _ _ => "No such file or directory"
  | .alreadyExists _ _ _ => "File exists"
  | .permissionDenied _ _ _ => "Permission denied"
  | .inappropriateType _ _ _ => "Not a directory or Is a directory"
  | .unsatisfiedConstraints _ _ => "Directory not empty or constraint not satisfied"
  | .invalidArgument _ _ d => if d.isEmpty then "Invalid argument" else d
  | .resourceVanished _ d => if d.isEmpty then "Broken pipe" else d
  | .userError msg => msg
  | e => e.toString

/-- Print `prog: path: reason` to stderr. -/
def reportFileError (prog path : String) (e : IO.Error) : IO Unit :=
  reportError prog s!"{path}: {describeError e}"

/-- Whether the error is a broken pipe (EPIPE), which applets such as `yes`
and `cat` should treat as a quiet, successful termination like GNU tools do
(right before dying of `SIGPIPE`). -/
def isBrokenPipe : IO.Error → Bool
  | .resourceVanished 32 _ => true
  | _ => false

/-- Print the standard `--help` text for an applet and succeed. -/
def helpAndExit (prog usage : String) : IO UInt32 := do
  IO.println s!"Usage: {usage}"
  IO.println s!"lutils {prog}, part of lutils {version} (Lean coreutils)"
  IO.println "A deliberately small, GNU-compatible subset; see the README."
  return exitOk

/-- Print the standard `--version` text and succeed. -/
def versionAndExit (prog : String) : IO UInt32 := do
  IO.println s!"{prog} (lutils) {version}"
  return exitOk

/-- Outcome of scanning an argv for `--help` / `--version`. -/
inductive MetaFlag where
  | none
  | help
  | version
  deriving BEq, DecidableEq

/-- Most GNU tools react to `--help`/`--version` anywhere before `--`. -/
def scanMetaFlags (args : List String) : MetaFlag :=
  match args with
  | [] => .none
  | "--help" :: _ => .help
  | "--version" :: _ => .version
  | "--" :: _ => .none
  | _ :: rest => scanMetaFlags rest

/-- Handle `--help`/`--version` if present. Returns `some code` when handled. -/
def handleMetaFlags (prog usage : String) (args : List String) :
    IO (Option UInt32) := do
  match scanMetaFlags args with
  | .help => some <$> helpAndExit prog usage
  | .version => some <$> versionAndExit prog
  | .none => return none

/-- Split argv at the first `--`: options may appear before it, and everything
after it is positional even when it starts with `-`. -/
def splitDoubleDash (args : List String) : List String × List String :=
  let (before, atAndAfter) := args.span (· != "--")
  (before, atAndAfter.drop 1)

/-- Read all remaining stdin as bytes. -/
def readStdinBytes : IO ByteArray := do
  let stdin ← IO.getStdin
  stdin.readBinToEnd

/-- Decode bytes as UTF-8, replacing invalid bytes with `?` instead of
failing. Text applets use this; byte-faithful paths never decode at all. -/
def decodeLossy (b : ByteArray) : String :=
  match String.fromUTF8? b with
  | some s => s
  | none => String.ofList (b.toList.map fun byte =>
      if byte < 128 then Char.ofNat byte.toNat else '?')

/-- Read all remaining stdin as text (lossy UTF-8). -/
def readStdinText : IO String := decodeLossy <$> readStdinBytes

/-- Read one operand: `-` means stdin, anything else is a file path. -/
def readOperandBytes (path : String) : IO ByteArray := do
  if path == "-" then
    readStdinBytes
  else
    -- Directories must error like GNU (`Is a directory`), not read as empty.
    let p : System.FilePath := path
    let md ← p.metadata
    if md.type == .dir then
      throw (IO.userError "Is a directory")
    IO.FS.readBinFile p

/-- A pure byte transformation with an arbitrary final result. The runner owns
all file and terminal effects; `step` and `finish` can be proved independently. -/
structure ByteStreamTransducer (State Result : Type) where
  initial : State
  step : State → ByteArray → State × ByteArray
  finish : State → ByteArray × Result

/-- Copy input bytes unchanged with constant transformation state. -/
def ByteStreamTransducer.identity : ByteStreamTransducer Unit Unit :=
  { initial := ()
    step := fun _ input => ((), input)
    finish := fun _ => (ByteArray.empty, ()) }

/-- A read size that cannot be zero. -/
structure ByteChunkSize where
  value : USize
  positive : 0 < value

def ByteChunkSize.fourMiB : ByteChunkSize :=
  ⟨4 * 1024 * 1024, by native_decide⟩

/-- Open an operand as a bounded byte source. -/
def operandChunkReader (path : String) (chunkSize : ByteChunkSize) : IO (IO ByteArray) := do
  if path == "-" then
    let input ← IO.getStdin
    return input.read chunkSize.value
  let file : System.FilePath := path
  let metadata ← file.metadata
  if metadata.type == .dir then throw (IO.userError "Is a directory")
  let input ← IO.FS.Handle.mk file .read
  return input.read chunkSize.value

/-- Run a pure byte transducer over bounded reads and write each result chunk.
The caller chooses a positive chunk size appropriate to its workload. -/
def runByteStream {State Result : Type} (path : String) (chunkSize : ByteChunkSize)
    (transducer : ByteStreamTransducer State Result) : IO Result := do
  let readChunk ← operandChunkReader path chunkSize
  let output ← IO.getStdout
  let mut state := transducer.initial
  repeat
    let input ← readChunk
    if input.isEmpty then break
    let (next, bytes) := transducer.step state input
    output.write bytes
    state := next
  let (finalBytes, result) := transducer.finish state
  output.write finalBytes
  output.flush
  return result

/-- Like `readOperandBytes` but decoded as lossy UTF-8 text. -/
def readOperandText (path : String) : IO String :=
  decodeLossy <$> readOperandBytes path

/-- Write bytes to stdout, flushing afterwards. -/
def writeStdout (b : ByteArray) : IO Unit := do
  let stdout ← IO.getStdout
  stdout.write b
  stdout.flush

/-- Write text to stdout, flushing afterwards. -/
def putStr (s : String) : IO Unit := do
  let stdout ← IO.getStdout
  stdout.putStr s
  stdout.flush

/-- Lines of a text, without their terminating `\n`, plus whether the text
ended with a newline. An empty text has no lines at all. -/
def linesOf (s : String) : List String × Bool :=
  if s.isEmpty then
    ([], false)
  else
    let endsNl := s.endsWith "\n"
    let parts := s.splitToList (· == '\n')
    let parts := if endsNl then parts.dropLast else parts
    (parts, endsNl)

/-- Inverse of `linesOf`: join lines with `\n`, restoring the final newline
only when `endsNl`. -/
def unlinesOf (lines : List String) (endsNl : Bool) : String :=
  match lines with
  | [] => ""
  | _ =>
      let joined := "\n".intercalate lines
      if endsNl then joined ++ "\n" else joined

/-- ASCII whitespace, matching the POSIX locale notion of a word separator. -/
def isAsciiSpace (c : Char) : Bool :=
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\x0b' || c == '\x0c'

/-- Split a string into whitespace-separated words. -/
def wordsOf (s : String) : List String :=
  (s.splitToList isAsciiSpace).filter (!·.isEmpty)

/-- Zero-pad (or space-pad) a decimal string on the left to `width`. -/
def padLeft (width : Nat) (fill : Char) (s : String) : String :=
  if s.length >= width then s
  else String.ofList (List.replicate (width - s.length) fill) ++ s

/-- Drain a list of applets' operands (default `["-"]` when empty, the usual
"read stdin" convention). -/
def operandsOrStdin (files : List String) : List String :=
  if files.isEmpty then ["-"] else files

/-- Lowercase hexadecimal encoding of a byte array, two digits per byte. -/
def hexEncode (b : ByteArray) : String := Id.run do
  let digits : Vector Char 16 :=
    #v['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']
  let mut out := ""
  for byte in b do
    out := out.push (digits.get ⟨byte.toNat / 16, by
      have h := UInt8.toNat_lt byte
      omega⟩)
    out := out.push (digits.get ⟨byte.toNat % 16, by omega⟩)
  return out

end Lutils
