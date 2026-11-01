/- Sort utility implementation (subset: whole-line keys only. Field keys via
`-k`/`--key`, `-g`/`-h`/`-M`/`-V`/`-R` orderings, and locale collation are
deferred; comparisons are bytewise as in the C locale). -/
import Lutils.Shared.Common

namespace Lutils

private structure SortOptions where
  reverse : Bool := false
  unique : Bool := false
  ignoreCase : Bool := false
  ignoreLeadingBlanks : Bool := false
  ignoreNonprinting : Bool := false
  dictionaryOrder : Bool := false
  numeric : Bool := false
  stable : Bool := false
  check : Bool := false
  checkQuiet : Bool := false
  zero : Bool := false
  output : Option String := none
  separator : Option Char := none
  files : List String := []

private def isBlankByte (b : UInt8) : Bool := b == 32 || b == 9

private def isDigitByte (b : UInt8) : Bool := 48 ≤ b && b ≤ 57

private def isPrintableByte (b : UInt8) : Bool := 32 ≤ b && b ≤ 126

private def isAlnumByte (b : UInt8) : Bool :=
  isDigitByte b || (97 ≤ b && b ≤ 122) || (65 ≤ b && b ≤ 90)

private def toUpperByte (b : UInt8) : UInt8 :=
  if 97 ≤ b && b ≤ 122 then b - 32 else b

/-- The whole-line key after the `-b`, `-d`, `-i`, and `-f` transforms.
Lines are byte strings throughout: `sort` must neither decode nor alter
input bytes it does not understand. -/
def sortKey (opts : SortOptions) (line : ByteArray) : List UInt8 := Id.run do
  let mut bytes := line.toList
  if opts.ignoreLeadingBlanks then
    bytes := bytes.dropWhile isBlankByte
  if opts.dictionaryOrder then
    bytes := bytes.filter (fun b => isAlnumByte b || isBlankByte b)
  if opts.ignoreNonprinting then
    bytes := bytes.filter isPrintableByte
  if opts.ignoreCase then
    bytes := bytes.map toUpperByte
  return bytes

/-- A leading number as `sort -n` sees it: sign, integer digits, fraction. -/
private structure NumParts where
  negative : Bool
  intPart : List UInt8
  fracPart : List UInt8

private def parseNumeric (line : ByteArray) : NumParts := Id.run do
  let mut bytes := line.toList.dropWhile isBlankByte
  let mut negative := false
  if bytes.head? == some 45 then
    negative := true
    bytes := bytes.tail
  let intDigits := bytes.takeWhile isDigitByte
  bytes := bytes.drop intDigits.length
  let mut fracDigits : List UInt8 := []
  if bytes.head? == some 46 then
    fracDigits := bytes.tail.takeWhile isDigitByte
  return ⟨negative, intDigits, fracDigits⟩

private def numSign (n : NumParts) : Int :=
  if (n.intPart.all (· == 48)) && (n.fracPart.all (· == 48)) then 0
  else if n.negative then -1 else 1

private def compareMagnitude (a b : NumParts) : Ordering :=
  let ai := a.intPart.dropWhile (· == 48)
  let bi := b.intPart.dropWhile (· == 48)
  if ai.length != bi.length then
    if ai.length < bi.length then .lt else .gt
  else if ai != bi then
    compare ai bi
  else
    let width := max a.fracPart.length b.fracPart.length
    let af := a.fracPart ++ List.replicate (width - a.fracPart.length) 48
    let bf := b.fracPart ++ List.replicate (width - b.fracPart.length) 48
    compare af bf

/-- Numerical comparison of the leading numbers of two lines. -/
def compareNumeric (a b : ByteArray) : Ordering :=
  let na := parseNumeric a
  let nb := parseNumeric b
  let (sa, sb) := (numSign na, numSign nb)
  if sa != sb then
    if sa < sb then .lt else .gt
  else if sa == 0 then
    .eq
  else
    let mag := compareMagnitude na nb
    if sa < 0 then mag.swap else mag

private def keyCompare (opts : SortOptions) (a b : ByteArray) : Ordering :=
  if opts.numeric then compareNumeric a b
  else compare (sortKey opts a) (sortKey opts b)

/-- Key comparison with the last-resort whole-line comparison. The
last-resort comparison is disabled by `-s` and by `-u` (so the first of
an equal-key run in the input is the one `-u` keeps); `-r` reverses the
whole result. -/
def sortCompare (opts : SortOptions) (a b : ByteArray) : Ordering :=
  let keyed := keyCompare opts a b
  let ordered := if keyed != .eq then keyed
    else if opts.stable || opts.unique then .eq
    else compare a.toList b.toList
  if opts.reverse then ordered.swap else ordered

/-- Sort lines with a stable merge sort under `sortCompare`. -/
def sortedLines (opts : SortOptions) (lines : List ByteArray) : List ByteArray :=
  lines.mergeSort (fun a b => sortCompare opts a b != .gt)

private def uniquified (opts : SortOptions) (lines : List ByteArray) :
    List ByteArray :=
  lines.foldl (fun kept line =>
    match kept.getLast? with
    | some last => if keyCompare opts last line == .eq then kept else kept ++ [line]
    | none => [line]) []

private def splitSortRecords (data : ByteArray) (zero : Bool) : List ByteArray := Id.run do
  let delim : UInt8 := if zero then 0 else 10
  let mut records : List ByteArray := []
  let mut current := ByteArray.empty
  for byte in data do
    if byte == delim then
      records := records ++ [current]
      current := ByteArray.empty
    else
      current := current.push byte
  if !data.isEmpty && data.data.getD (data.size - 1) 0 != delim then
    records := records ++ [current]
  return records

/-- `sort [OPTION]... [FILE]...`: sort lines of the concatenated inputs.
Failure exits with status 2, as GNU `sort` does; a failed `-c` check is 1. -/
def runSort : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "sort [OPTION]... [FILE]..." args then
    return code
  let mut opts : SortOptions := {}
  let arr := args.toArray
  let mut i := 0
  let mut literal := false
  let tryMsg := s!"Try '{prog} --help' for more information."
  let failWith (msg : String) : IO UInt32 := do
    reportError prog msg
    IO.eprintln tryMsg
    return exitUsage
  while i < arr.size do
    let arg := arr.getD i ""
    i := i + 1
    if literal then
      opts := { opts with files := opts.files ++ [arg] }
    else if arg == "--" then
      literal := true
    else if arg == "-" || !arg.startsWith "-" then
      opts := { opts with files := opts.files ++ [arg] }
    else if arg.startsWith "--" then
      let (name, value) := match arg.splitOn "=" with
        | n :: rest => (n, if rest.isEmpty then none else some ("=".intercalate rest))
        | [] => (arg, none)
      match name with
      | "--reverse" => opts := { opts with reverse := true }
      | "--unique" => opts := { opts with unique := true }
      | "--ignore-case" => opts := { opts with ignoreCase := true }
      | "--ignore-leading-blanks" => opts := { opts with ignoreLeadingBlanks := true }
      | "--ignore-nonprinting" => opts := { opts with ignoreNonprinting := true }
      | "--dictionary-order" => opts := { opts with dictionaryOrder := true }
      | "--numeric-sort" => opts := { opts with numeric := true }
      | "--stable" => opts := { opts with stable := true }
      | "--zero-terminated" => opts := { opts with zero := true }
      | "--merge" => pure ()
      | "--check" =>
          match value with
          | none | some "diagnose-first" =>
              opts := { opts with check := true, checkQuiet := false }
          | some "quiet" | some "silent" =>
              opts := { opts with check := true, checkQuiet := true }
          | some bad =>
              reportError prog s!"invalid argument '{bad}' for '--check'"
              IO.eprintln "Valid arguments are:"
              IO.eprintln "  - 'quiet', 'silent'"
              IO.eprintln "  - 'diagnose-first'"
              IO.eprintln tryMsg
              return exitFail
      | "--output" | "--field-separator" | "--key" =>
          let value ← match value with
            | some v => pure v
            | none =>
                match arr[i]? with
                | some v => i := i + 1; pure v
                | none =>
                    reportError prog s!"option '{name}' requires an argument"
                    IO.eprintln tryMsg
                    return exitUsage
          if name == "--output" then
            opts := { opts with output := some value }
          else if name == "--field-separator" then
            opts := { opts with separator := value.toList.head? }
          else
            return ← failWith "option '--key' is not yet implemented in lutils"
      | "--general-numeric-sort" | "--human-numeric-sort" | "--month-sort"
      | "--version-sort" | "--random-sort" =>
          return ← failWith s!"option '{name}' is not yet implemented in lutils"
      | _ =>
          reportError prog s!"unrecognized option '{arg}'"
          IO.eprintln tryMsg
          return exitUsage
    else
      let chars := (arg.drop 1).toString.toList
      let mut j := 0
      let mut consumedNext := false
      while j < chars.length do
        let c := chars.getD j ' '
        j := j + 1
        match c with
        | 'r' => opts := { opts with reverse := true }
        | 'u' => opts := { opts with unique := true }
        | 'f' => opts := { opts with ignoreCase := true }
        | 'b' => opts := { opts with ignoreLeadingBlanks := true }
        | 'i' => opts := { opts with ignoreNonprinting := true }
        | 'd' => opts := { opts with dictionaryOrder := true }
        | 'n' => opts := { opts with numeric := true }
        | 's' => opts := { opts with stable := true }
        | 'z' => opts := { opts with zero := true }
        | 'm' => pure ()
        | 'c' => opts := { opts with check := true }
        | 'C' => opts := { opts with check := true, checkQuiet := true }
        | 'o' | 't' | 'k' =>
            let rest := String.ofList (chars.drop j)
            let value ←
              if !rest.isEmpty then pure rest
              else match arr[i]? with
                | some v => consumedNext := true; pure v
                | none =>
                    reportError prog s!"option requires an argument -- '{c}'"
                    IO.eprintln tryMsg
                    return exitUsage
            if c == 'o' then
              opts := { opts with output := some value }
            else if c == 't' then
              opts := { opts with separator := value.toList.head? }
            else
              return ← failWith "option '-k' is not yet implemented in lutils"
            j := chars.length
        | 'g' | 'h' | 'M' | 'V' | 'R' =>
            return ← failWith s!"option '-{c}' is not yet implemented in lutils"
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            IO.eprintln tryMsg
            return exitUsage
      if consumedNext then i := i + 1
  -- Read every input first, so `-o` may name an input file.
  let mut inputs : List (String × List ByteArray) := []
  for file in operandsOrStdin opts.files do
    try
      let data ← readOperandBytes file
      inputs := inputs ++ [(file, splitSortRecords data opts.zero)]
    catch e =>
      reportError prog s!"cannot read: {file}: {describeError e}"
      return exitUsage
  let delim : UInt8 := if opts.zero then 0 else 10
  if opts.check then
    for (file, lines) in inputs do
      let mut previous : Option ByteArray := none
      let mut lineNo := 0
      for line in lines do
        lineNo := lineNo + 1
        match previous with
        | some prev =>
            let disordered := sortCompare opts prev line == .gt ||
              (opts.unique && keyCompare opts prev line == .eq)
            if disordered then
              if !opts.checkQuiet then
                let stderr ← IO.getStderr
                stderr.write (s!"{prog}: {file}:{lineNo}: disorder: ".toUTF8 ++
                  line ++ "\n".toUTF8)
              return exitFail
        | none => pure ()
        previous := some line
    return exitOk
  let allLines := inputs.foldl (fun acc (_, lines) => acc ++ lines) []
  let sorted := sortedLines opts allLines
  let result := if opts.unique then uniquified opts sorted else sorted
  let rendered := result.foldl (fun acc line => acc ++ line ++ ByteArray.mk #[delim])
    ByteArray.empty
  try
    match opts.output with
    | some path => IO.FS.writeBinFile path rendered
    | none => writeStdout rendered
    return exitOk
  catch e =>
    if isBrokenPipe e then return exitOk
    reportError prog (describeError e)
    return exitUsage

/-- Multicall registration for `sort`. -/
abbrev SortApplet := AppletTag "sort" runSort

end Lutils
