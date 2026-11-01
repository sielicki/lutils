/- Cksum utility implementation (subset: no `blake2b`, `sm3`, or `sha3` yet). -/
import Lutils.Shared.Checksum
import Lutils.Shared.LegacySum

namespace Lutils

open LegacySum

private inductive CksumKind where
  | crc | crc32b | bsd | sysv
  | digest (alg : Checksum.Algorithm)
  | unsupported (name : String)
  | invalid (name : String)

/-- Split out `-a`/`--algorithm` and `-l`/`--length` (in their separate,
joined, and `=` forms) from the options preceding `--`. -/
private def extractAlg (args : List String) :
    Option String × Option String × List String := Id.run do
  let (before, after) := args.span (· != "--")
  let mut alg : Option String := none
  let mut len : Option String := none
  let mut rest : List String := []
  let mut i := 0
  let arr := before.toArray
  while i < arr.size do
    let arg := arr.getD i ""
    if arg == "-a" || arg == "--algorithm" then
      alg := arr[i + 1]?
      i := i + 2
    else if arg.startsWith "--algorithm=" then
      alg := some (arg.drop "--algorithm=".length).toString
      i := i + 1
    else if arg.startsWith "-a" && arg.length > 2 then
      alg := some (arg.drop 2).toString
      i := i + 1
    else if arg == "-l" || arg == "--length" then
      len := arr[i + 1]?
      i := i + 2
    else if arg.startsWith "--length=" then
      len := some (arg.drop "--length=".length).toString
      i := i + 1
    else if arg.startsWith "-l" && arg.length > 2 then
      len := some (arg.drop 2).toString
      i := i + 1
    else
      rest := rest ++ [arg]
      i := i + 1
  let tail := if after.isEmpty then after else after
  return (alg, len, rest ++ tail)

private def hasCheck (args : List String) : Bool :=
  let (before, _) := args.span (· != "--")
  before.any fun arg =>
    arg == "--check" ||
      (arg.startsWith "-" && !arg.startsWith "--" && arg.length > 1 &&
        (arg.drop 1).toString.toList.all (fun c => "bctzw".contains c) &&
        (arg.drop 1).toString.contains 'c')

private def resolveKind (alg : Option String) (len : Option String) : CksumKind :=
  match alg with
  | none => .crc
  | some "crc" => .crc
  | some "crc32b" => .crc32b
  | some "bsd" => .bsd
  | some "sysv" => .sysv
  | some "md5" => .digest .md5
  | some "sha1" => .digest .sha1
  | some "sha224" => .digest .sha224
  | some "sha256" => .digest .sha256
  | some "sha384" => .digest .sha384
  | some "sha512" => .digest .sha512
  | some "sha2" =>
      match len with
      | some "224" => .digest .sha224
      | some "256" => .digest .sha256
      | some "384" => .digest .sha384
      | some "512" => .digest .sha512
      | _ => .unsupported "sha2"
  | some "blake2b" => .unsupported "blake2b"
  | some "sm3" => .unsupported "sm3"
  | some "sha3" => .unsupported "sha3"
  | some name => .invalid name

private def invalidAlg (prog name : String) : IO UInt32 := do
  reportError prog s!"invalid argument '{name}' for '--algorithm'"
  IO.eprintln "Valid arguments are:"
  for valid in ["bsd", "sysv", "crc", "crc32b", "md5", "sha1", "sha224", "sha256",
      "sha384", "sha512", "sha2", "sha3", "blake2b", "sm3"] do
    IO.eprintln s!"  - '{valid}'"
  IO.eprintln s!"Try '{prog} --help' for more information."
  return exitFail

/-- The non-digest `cksum` algorithms, whose `--check` GNU does not support
and whose option surface is only binary/text/tag/zero decoration. -/
private def runLegacy (kind : CksumKind) (prog : String) (args : List String) :
    IO UInt32 := do
  let mut zero := false
  let mut checkSeen := false
  let mut files : List String := []
  let (before, positional) := splitDoubleDash args
  for arg in before do
    if arg == "-" || !arg.startsWith "-" then
      files := files ++ [arg]
    else if arg.startsWith "--" then
      match arg with
      | "--binary" | "--text" | "--tag" | "--untagged" => pure ()
      | "--zero" => zero := true
      | "--check" => checkSeen := true
      | _ =>
          reportError prog s!"unrecognized option '{arg}'"
          IO.eprintln s!"Try '{prog} --help' for more information."
          return exitFail
    else
      for c in (arg.drop 1).toString.toList do
        match c with
        | 'b' | 't' => pure ()
        | 'z' => zero := true
        | 'c' => checkSeen := true
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            IO.eprintln s!"Try '{prog} --help' for more information."
            return exitFail
  if checkSeen then
    reportError prog "--check is not supported with --algorithm={bsd,sysv,crc,crc32b}"
    return exitFail
  let allFiles := files ++ positional
  let mut good := true
  for file in operandsOrStdin allFiles do
    try
      let data ← readOperandBytes file
      let name := if allFiles.isEmpty then none else some file
      let line := match kind with
        | .bsd => renderBsd data name zero
        | .sysv => renderSysv data name zero
        | .crc32b =>
            s!"{crc32b data} {data.size}" ++
              (match name with | some n => " " ++ n | none => "") ++
              if zero then "\x00" else "\n"
        | _ =>
            s!"{cksumCrc data} {data.size}" ++
              (match name with | some n => " " ++ n | none => "") ++
              if zero then "\x00" else "\n"
      putStr line
    catch e =>
      reportFileError prog file e
      good := false
  return if good then exitOk else exitFail

/-- `cksum [OPTION]... [FILE]...`: POSIX CRC by default; digest algorithms
via `-a`, with tagged output unless `--untagged` is given. -/
def runCksum : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "cksum [OPTION]... [FILE]..." args then
    return code
  let (alg, len, rest) := extractAlg args
  match alg, len with
  | _, some _ =>
      unless alg == some "blake2b" || alg == some "sha2" || alg == some "sha3" do
        reportError prog "--length is only supported with --algorithm blake2b, sha2, or sha3"
        return exitFail
  | _, none => pure ()
  match resolveKind alg len with
  | .invalid name => invalidAlg prog name
  | .unsupported "sha2" =>
      reportError prog "--algorithm=sha2 requires specifying --length 224, 256, 384, or 512"
      return exitFail
  | .unsupported name =>
      reportError prog s!"algorithm '{name}' is not yet implemented in lutils"
      return exitFail
  | .digest algorithm => Checksum.runCksum algorithm prog rest
  | kind =>
      if alg.isNone && hasCheck rest then
        Checksum.runCksumCheckAny prog rest
      else
        runLegacy kind prog rest

/-- Multicall registration for `cksum`. -/
abbrev CksumApplet := AppletTag "cksum" runCksum

end Lutils
