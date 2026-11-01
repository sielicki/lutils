/- Uniq utility implementation (subset: no obsolete `+N`/`-N` operand syntax). -/
import Lutils.Shared.Common

namespace Lutils

private inductive SeparateMode where
  | none | separate | prepend | append | both
  deriving BEq

private structure UniqOptions where
  count : Bool := false
  repeated : Bool := false
  allRepeated : Bool := false
  group : Bool := false
  mode : SeparateMode := .none
  unique : Bool := false
  ignoreCase : Bool := false
  skipFields : Nat := 0
  skipChars : Nat := 0
  checkChars : Option Nat := none
  zero : Bool := false
  files : List String := []

/-- Split a record into characters, each keeping its original bytes.
Invalid UTF-8 falls back to one byte per character, like the C locale.
Keys and output are built from these units so arbitrary input bytes are
never decoded or replaced. -/
private def charUnits (record : ByteArray) : List ByteArray :=
  match String.fromUTF8? record with
  | some s => s.toList.map (fun c => (String.singleton c).toUTF8)
  | none => record.toList.map (fun b => ByteArray.mk #[b])

private def isBlankUnit (unit : ByteArray) : Bool :=
  unit == " ".toUTF8 || unit == "\t".toUTF8

private def foldUnit (unit : ByteArray) : ByteArray :=
  match String.fromUTF8? unit with
  | some s => s.toUpper.toUTF8
  | none => unit

/-- Skip `n` fields: each field is a run of blanks followed by a run of
non-blanks, matching `uniq`'s field notion. -/
def skipFieldsOf (n : Nat) (units : List ByteArray) : List ByteArray := Id.run do
  let mut rest := units
  for _ in [0:n] do
    rest := rest.dropWhile isBlankUnit
    rest := rest.dropWhile (fun u => !isBlankUnit u)
  return rest

/-- The comparison key for a line after field/character skipping, optional
truncation, and optional case folding. -/
def uniqKey (opts : UniqOptions) (line : ByteArray) : List ByteArray :=
  let skipped := (skipFieldsOf opts.skipFields (charUnits line)).drop opts.skipChars
  let limited := match opts.checkChars with
    | some w => skipped.take w
    | none => skipped
  if opts.ignoreCase then limited.map foldUnit else limited

private def splitRecords (data : ByteArray) (zero : Bool) : List ByteArray := Id.run do
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

/-- Consecutive runs sharing a key, keeping every line for `-D`/`--group`. -/
def uniqGroups (opts : UniqOptions) (lines : List ByteArray) :
    List (List ByteArray) :=
  lines.foldl (fun groups line =>
    match groups with
    | [] => [[line]]
    | current :: earlier =>
        match current.head? with
        | some first =>
            if uniqKey opts first == uniqKey opts line then
              (current ++ [line]) :: earlier
            else
              [line] :: current :: earlier
        | none => [line] :: earlier) [] |>.reverse

private def renderGroups (opts : UniqOptions) (lines : List ByteArray) : ByteArray :=
  let delim : UInt8 := if opts.zero then 0 else 10
  let terminator := ByteArray.mk #[delim]
  let groups := uniqGroups opts lines
  let blankBefore (i : Nat) : ByteArray :=
    match opts.mode with
    | .separate => if i == 0 then ByteArray.empty else terminator
    | .prepend => terminator
    | .both => terminator
    | _ => ByteArray.empty
  let blankAfter (isLast : Bool) : ByteArray :=
    match opts.mode with
    | .append => terminator
    | .both => if isLast then terminator else ByteArray.empty
    | _ => ByteArray.empty
  Id.run do
    let mut out := ByteArray.empty
    if opts.allRepeated || opts.group then
      let shown := if opts.group then groups else groups.filter (fun g => g.length > 1)
      for i in [0:shown.length] do
        let group := shown.getD i []
        out := out ++ blankBefore i
        for line in group do
          out := out ++ line ++ terminator
        out := out ++ blankAfter (i + 1 == shown.length)
    else
      for group in groups do
        let keep := (!opts.repeated || group.length > 1) &&
          (!opts.unique || group.length == 1)
        if keep then
          match group.head? with
          | some line =>
              if opts.count then
                out := out ++ (padLeft 7 ' ' (toString group.length) ++ " ").toUTF8 ++
                  line ++ terminator
              else
                out := out ++ line ++ terminator
          | none => pure ()
    return out

/-- `uniq [OPTION]... [INPUT [OUTPUT]]`: filter adjacent duplicate lines. -/
def runUniq : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "uniq [OPTION]... [INPUT [OUTPUT]]" args then
    return code
  let mut opts : UniqOptions := {}
  let arr := args.toArray
  let mut i := 0
  let mut literal := false
  let tryMsg := s!"Try '{prog} --help' for more information."
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
      | "--count" => opts := { opts with count := true }
      | "--repeated" => opts := { opts with repeated := true }
      | "--unique" => opts := { opts with unique := true }
      | "--ignore-case" => opts := { opts with ignoreCase := true }
      | "--zero-terminated" => opts := { opts with zero := true }
      | "--all-repeated" =>
          match value with
          | none | some "none" => opts := { opts with allRepeated := true }
          | some "separate" => opts := { opts with allRepeated := true, mode := .separate }
          | some "prepend" => opts := { opts with allRepeated := true, mode := .prepend }
          | some bad =>
              reportError prog s!"invalid argument '{bad}' for '--all-repeated'"
              IO.eprintln tryMsg
              return exitFail
      | "--group" =>
          match value with
          | none | some "separate" => opts := { opts with group := true, mode := .separate }
          | some "prepend" => opts := { opts with group := true, mode := .prepend }
          | some "append" => opts := { opts with group := true, mode := .append }
          | some "both" => opts := { opts with group := true, mode := .both }
          | some bad =>
              reportError prog s!"invalid argument '{bad}' for '--group'"
              IO.eprintln tryMsg
              return exitFail
      | "--skip-fields" | "--skip-chars" | "--check-chars" =>
          let value ← match value with
            | some v => pure v
            | none =>
                match arr[i]? with
                | some v => i := i + 1; pure v
                | none =>
                    reportError prog s!"option '{name}' requires an argument"
                    IO.eprintln tryMsg
                    return exitFail
          let what := if name == "--skip-fields" then "fields to skip"
            else if name == "--skip-chars" then "bytes to skip" else "bytes to compare"
          match value.toNat? with
          | none =>
              reportError prog s!"{value}: invalid number of {what}"
              return exitFail
          | some n =>
              opts := if name == "--skip-fields" then { opts with skipFields := n }
                else if name == "--skip-chars" then { opts with skipChars := n }
                else { opts with checkChars := some n }
      | _ =>
          reportError prog s!"unrecognized option '{arg}'"
          IO.eprintln tryMsg
          return exitFail
    else
      let chars := (arg.drop 1).toString.toList
      let mut j := 0
      let mut consumedNext := false
      while j < chars.length do
        let c := chars.getD j ' '
        j := j + 1
        match c with
        | 'c' => opts := { opts with count := true }
        | 'd' => opts := { opts with repeated := true }
        | 'D' => opts := { opts with allRepeated := true }
        | 'u' => opts := { opts with unique := true }
        | 'i' => opts := { opts with ignoreCase := true }
        | 'z' => opts := { opts with zero := true }
        | 'f' | 's' | 'w' =>
            let rest := String.ofList (chars.drop j)
            let value ←
              if !rest.isEmpty then pure rest
              else match arr[i]? with
                | some v => consumedNext := true; pure v
                | none =>
                    reportError prog s!"option requires an argument -- '{c}'"
                    IO.eprintln tryMsg
                    return exitFail
            let what := if c == 'f' then "fields to skip"
              else if c == 's' then "bytes to skip" else "bytes to compare"
            match value.toNat? with
            | none =>
                reportError prog s!"{value}: invalid number of {what}"
                return exitFail
            | some n =>
                opts := if c == 'f' then { opts with skipFields := n }
                  else if c == 's' then { opts with skipChars := n }
                  else { opts with checkChars := some n }
            j := chars.length
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            IO.eprintln tryMsg
            return exitFail
      if consumedNext then i := i + 1
  if opts.count && opts.allRepeated then
    reportError prog "printing all duplicated lines and repeat counts is meaningless"
    IO.eprintln tryMsg
    return exitFail
  if opts.files.length > 2 then
    reportError prog s!"extra operand '{opts.files.getD 2 ""}'"
    IO.eprintln tryMsg
    return exitFail
  let input := opts.files.head?.getD "-"
  try
    let data ← readOperandBytes input
    let output := renderGroups opts (splitRecords data opts.zero)
    match (opts.files[1]? : Option String) with
    | some path => IO.FS.writeBinFile path output
    | none => writeStdout output
    return exitOk
  catch e =>
    if isBrokenPipe e then return exitOk
    reportFileError prog input e
    return exitFail

/-- Multicall registration for `uniq`. -/
abbrev UniqApplet := AppletTag "uniq" runUniq

end Lutils
