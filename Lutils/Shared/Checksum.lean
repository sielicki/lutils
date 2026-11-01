import Lutils.Shared.Sha2
import Lutils.Shared.Sha512
import Lutils.Shared.Sha1
import Lutils.Shared.Md5

namespace Lutils.Checksum

/-- A digest algorithm as seen by the GNU `*sum` frontends: the name printed
by `--tag`, the lowercase hexadecimal digest length, and the digest function.
Every frontend shares option parsing, manifest rendering, and `--check`;
only these three facts differ. -/
structure Algorithm where
  tagName : String
  hexLength : Nat
  digest : ByteArray → String

def Algorithm.md5 : Algorithm := ⟨"MD5", 32, Md5.digest⟩
def Algorithm.sha1 : Algorithm := ⟨"SHA1", 40, Sha1.digest⟩
def Algorithm.sha224 : Algorithm := ⟨"SHA224", 56, Sha2.digest .sha224⟩
def Algorithm.sha256 : Algorithm := ⟨"SHA256", 64, Sha2.digest .sha256⟩
def Algorithm.sha384 : Algorithm := ⟨"SHA384", 96, Sha512.digest .sha384⟩
def Algorithm.sha512 : Algorithm := ⟨"SHA512", 128, Sha512.digest .sha512⟩

/-- Every supported digest algorithm, for `cksum` manifest auto-detection. -/
def algorithms : List Algorithm :=
  [.md5, .sha1, .sha224, .sha256, .sha384, .sha512]

structure Options where
  check : Bool := false
  binary : Bool := false
  modeSpecified : Bool := false
  textSpecified : Bool := false
  tag : Bool := false
  tagSpecified : Bool := false
  zero : Bool := false
  quiet : Bool := false
  status : Bool := false
  warn : Bool := false
  strict : Bool := false
  ignoreMissing : Bool := false
  files : List String := []

private def expandShort (arg : String) : List String :=
  if arg.startsWith "-" && !arg.startsWith "--" && arg.length > 2 &&
      (arg.drop 1).toString.toList.all (fun c => "bctzw".contains c) then
    (arg.drop 1).toString.toList.map (fun c => "-" ++ String.singleton c)
  else [arg]

/-- Parse `*sum` options. In `cksum` style, digest output is tagged by
default and `--untagged` is accepted; the plain `*sum` applets reject it. -/
private def parse (prog : String) (cksumStyle : Bool) (args : List String) :
    IO (Option Options) :=
  let (before, after) := args.span (· != "--")
  go { tag := cksumStyle } false (before.flatMap expandShort ++ after)
where
  go (opts : Options) (literal : Bool) : List String → IO (Option Options)
    | [] => return some opts
    | arg :: rest =>
      if literal then go { opts with files := opts.files ++ [arg] } true rest
      else if arg == "--" then go opts true rest
      else if arg == "--check" || arg == "-c" then go { opts with check := true } false rest
      else if arg == "--binary" || arg == "-b" then
        go { opts with binary := true, modeSpecified := true, textSpecified := false } false rest
      else if arg == "--text" || arg == "-t" then
        go { opts with binary := false, modeSpecified := true, textSpecified := true } false rest
      else if arg == "--tag" then go { opts with tag := true, tagSpecified := true } false rest
      else if arg == "--untagged" && cksumStyle then
        go { opts with tag := false } false rest
      else if arg == "--zero" || arg == "-z" then go { opts with zero := true } false rest
      else if arg == "--quiet" then go { opts with quiet := true } false rest
      else if arg == "--status" then go { opts with status := true } false rest
      else if arg == "--warn" || arg == "-w" then go { opts with warn := true } false rest
      else if arg == "--strict" then go { opts with strict := true } false rest
      else if arg == "--ignore-missing" then go { opts with ignoreMissing := true } false rest
      else if arg.startsWith "-" && arg != "-" then do
        if arg.length == 2 && !arg.startsWith "--" then
          reportError prog s!"invalid option -- '{(arg.drop 1).toString}'"
        else
          reportError prog s!"unrecognized option '{arg}'"
        IO.eprintln s!"Try '{prog} --help' for more information."
        return none
      else go { opts with files := opts.files ++ [arg] } false rest

private def escaped (name : String) : String :=
  (name.replace "\\" "\\\\").replace "\n" "\\n"

private def needsEscape (name : String) : Bool :=
  name.contains '\\' || name.contains '\n'

private def render (alg : Algorithm) (opts : Options) (name hash : String) : String :=
  let escape := !opts.zero && needsEscape name
  let display := if escape then escaped name else name
  let lead := if escape then "\\" else ""
  let body := if opts.tag then
    s!"{alg.tagName} ({display}) = {hash}"
  else
    s!"{hash} {if opts.binary then "*" else " "}{display}"
  lead ++ body ++ if opts.zero then "\x00" else "\n"

private def isHex (c : Char) : Bool :=
  ('0' ≤ c && c ≤ '9') || ('a' ≤ c && c ≤ 'f') || ('A' ≤ c && c ≤ 'F')

private def unescapeChars : List Char → List Char
  | '\\' :: 'n' :: rest => '\n' :: unescapeChars rest
  | '\\' :: '\\' :: rest => '\\' :: unescapeChars rest
  | c :: rest => c :: unescapeChars rest
  | [] => []

private def unescape (s : String) : String := String.ofList (unescapeChars s.toList)

/-- A checksum line after its algorithm and digest syntax have been checked. -/
private structure ManifestEntry where
  name : String
  expected : String
  alg : Algorithm

private def parseLine (alg : Algorithm) (line : String) : Option ManifestEntry := do
  let marked := line.startsWith "\\"
  let line := if marked then line.drop 1 |>.toString else line
  let width := alg.hexLength
  if line.startsWith s!"{alg.tagName} (" then
    let lead := s!"{alg.tagName} ("
    let rest := (line.drop lead.length).toString
    let pieces := rest.splitOn ") = "
    match pieces with
    | [name, hash] =>
      if hash.length == width && hash.toList.all isHex then
        some ⟨if marked then unescape name else name, hash.toLower, alg⟩
      else none
    | _ => none
  else if line.length >= width + 2 then
    let hash := (line.take width).toString
    let mode := (line.drop width).take 2 |>.toString
    if hash.toList.all isHex && mode.startsWith " " then
      let name := (line.drop (width + (if mode == "  " || mode == " *" then 2 else 1))).toString
      if name.isEmpty then none else some ⟨if marked then unescape name else name, hash.toLower, alg⟩
    else none
  else none

/-- Parse a manifest line with any supported algorithm, as plain
`cksum --check` does: tagged lines name their algorithm, and untagged
lines are identified by digest width. -/
private def parseLineAny (line : String) : Option ManifestEntry :=
  algorithms.findSome? (fun alg => parseLine alg line)

private def checkFile (prog : String) (parseFn : String → Option ManifestEntry)
    (warnName : Option String) (opts : Options)
    (listName : String) : IO Bool := do
  let contents ← try readOperandBytes listName catch e =>
    reportFileError prog listName e
    return false
  let text := decodeLossy contents
  let displayList := if listName == "-" then "'standard input'" else listName
  let mut parsed := 0
  let mut verified := 0
  let mut missing := 0
  let mut mismatched := 0
  let mut malformed := 0
  let mut lineNumber := 0
  for line in (text.splitOn "\n") do
    lineNumber := lineNumber + 1
    let line := if line.endsWith "\r" then (line.dropEnd 1).toString else line
    if line.isEmpty then continue
    match parseFn line with
    | none =>
      malformed := malformed + 1
      if opts.warn && !opts.status then
        let kind := match warnName with
          | some name => s!"improperly formatted {name} checksum line"
          | none => "improperly formatted checksum line"
        reportError prog s!"{displayList}: {lineNumber}: {kind}"
    | some entry =>
      parsed := parsed + 1
      let data ← try some <$> readOperandBytes entry.name catch e =>
        if !opts.ignoreMissing then reportFileError prog entry.name e
        pure none
      match data with
      | none =>
        if !opts.ignoreMissing then
          missing := missing + 1
          if !opts.status then putStr s!"{entry.name}: FAILED open or read\n"
      | some bytes =>
        verified := verified + 1
        let ok := entry.alg.digest bytes == entry.expected
        if !ok then mismatched := mismatched + 1
        if !opts.status && (!ok || !opts.quiet) then
          putStr s!"{entry.name}: {if ok then "OK" else "FAILED"}\n"
  if parsed == 0 then
    reportError prog s!"{displayList}: no properly formatted checksum lines found"
    return false
  if !opts.status then
    if malformed > 0 then
      reportError prog s!"WARNING: {malformed} {if malformed == 1 then "line is" else "lines are"} improperly formatted"
    if missing > 0 then
      reportError prog s!"WARNING: {missing} listed {if missing == 1 then "file" else "files"} could not be read"
    if mismatched > 0 then
      reportError prog s!"WARNING: {mismatched} computed {if mismatched == 1 then "checksum" else "checksums"} did NOT match"
  if opts.ignoreMissing && verified == 0 then
    reportError prog s!"{displayList}: no file was verified"
    return false
  return missing == 0 && mismatched == 0 && (!opts.strict || malformed == 0)

/-- GNU-compatible checksum frontend shared by the `*sum` applets.
In `cksum` style the output is tagged unless `--untagged` is given. -/
def runWith (alg : Algorithm) (cksumStyle : Bool) (prog : String)
    (args : List String) : IO UInt32 := do
  if let some code ← handleMetaFlags prog s!"{prog} [OPTION]... [FILE]..." args then return code
  let some opts ← parse prog cksumStyle args | return exitFail
  if opts.check && (opts.zero || opts.tagSpecified || opts.modeSpecified) then
    let message := if opts.zero then "the --zero option is not supported when verifying checksums"
      else if opts.tagSpecified then "the --tag option is meaningless when verifying checksums"
      else "the --binary and --text options are meaningless when verifying checksums"
    reportError prog message
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  if cksumStyle && opts.tag && opts.textSpecified then
    reportError prog "--text mode is only supported with --untagged"
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  if opts.tag && opts.textSpecified then
    reportError prog "--tag does not support --text mode"
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  if opts.check then
    let mut good := true
    for file in operandsOrStdin opts.files do
      if !(← checkFile prog (parseLine alg) (some alg.tagName) opts file) then good := false
    return if good then exitOk else exitFail
  if opts.quiet || opts.status || opts.warn || opts.strict || opts.ignoreMissing then
    let option := if opts.quiet then "--quiet" else if opts.status then "--status" else if opts.warn then "--warn" else if opts.strict then "--strict" else "--ignore-missing"
    reportError prog s!"the {option} option is meaningful only when verifying checksums"
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  let mut good := true
  for file in operandsOrStdin opts.files do
    try
      let bytes ← readOperandBytes file
      putStr (render alg opts file (alg.digest bytes))
    catch e =>
      reportFileError prog file e
      good := false
  return if good then exitOk else exitFail

/-- The plain `*sum` frontend: untagged output by default. -/
def run (alg : Algorithm) (prog : String) (args : List String) : IO UInt32 :=
  runWith alg false prog args

/-- The `cksum -a ALGORITHM` frontend: tagged output by default. -/
def runCksum (alg : Algorithm) (prog : String) (args : List String) : IO UInt32 :=
  runWith alg true prog args

/-- Plain `cksum --check`, which auto-detects each line's algorithm.
The caller has already confirmed that a `--check` option is present. -/
def runCksumCheckAny (prog : String) (args : List String) : IO UInt32 := do
  if let some code ← handleMetaFlags prog s!"{prog} [OPTION]... [FILE]..." args then return code
  let some opts ← parse prog true args | return exitFail
  if opts.zero || opts.tagSpecified || opts.modeSpecified then
    let message := if opts.zero then "the --zero option is not supported when verifying checksums"
      else if opts.tagSpecified then "the --tag option is meaningless when verifying checksums"
      else "the --binary and --text options are meaningless when verifying checksums"
    reportError prog message
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  let mut good := true
  for file in operandsOrStdin opts.files do
    if !(← checkFile prog parseLineAny none opts file) then good := false
  return if good then exitOk else exitFail

end Lutils.Checksum
