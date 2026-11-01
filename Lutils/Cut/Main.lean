/- Cut utility implementation (subset: single-byte delimiters; `-n` accepted
and ignored, as multibyte characters are never split). -/
import Lutils.Shared.Common

namespace Lutils

private inductive CutMode where
  | bytes | chars | fields

/-- A 1-based inclusive range; `none` as the end means "to the end". -/
private abbrev CutRange := Nat × Option Nat

private def numberedMsg (fields : Bool) : String :=
  if fields then "fields are numbered from 1"
  else "byte/character positions are numbered from 1"

private def valueMsg (fields : Bool) (item : String) : String :=
  if fields then s!"invalid field value '{item}'"
  else s!"invalid byte/character position '{item}'"

private def rangeMsg (fields : Bool) : String :=
  if fields then "invalid field range" else "invalid byte or character range"

/-- Parse a `cut` list such as `1,3-5,7-`, with GNU's error wording. -/
def parseCutList (fields : Bool) (spec : String) : Except String (List CutRange) := do
  let mut ranges : List CutRange := []
  for item in spec.splitOn "," do
    if item.isEmpty then
      throw (numberedMsg fields)
    else if item == "-" then
      throw "invalid range with no endpoint: -"
    else if item.startsWith "-" then
      let rest := (item.drop 1).toString
      match rest.toNat? with
      | none => throw (valueMsg fields item)
      | some 0 => throw (numberedMsg fields)
      | some m => ranges := ranges ++ [(1, some m)]
    else
      match item.splitOn "-" with
      | [single] =>
          match single.toNat? with
          | none => throw (valueMsg fields item)
          | some 0 => throw (numberedMsg fields)
          | some n => ranges := ranges ++ [(n, some n)]
      | [lo, hi] =>
          match lo.toNat? with
          | none => throw (valueMsg fields item)
          | some 0 => throw (numberedMsg fields)
          | some n =>
              if hi.isEmpty then
                ranges := ranges ++ [(n, none)]
              else
                match hi.toNat? with
                | none => throw (valueMsg fields item)
                | some 0 => throw (numberedMsg fields)
                | some m =>
                    if m < n then throw "invalid decreasing range"
                    ranges := ranges ++ [(n, some m)]
      | _ => throw (rangeMsg fields)
  return ranges

/-- Whether the 1-based position `i` is selected by any range. -/
def cutSelected (ranges : List CutRange) (i : Nat) : Bool :=
  ranges.any fun (lo, hi) => lo ≤ i && (match hi with | some h => i ≤ h | none => true)

theorem cutSelected_single (n : Nat) : cutSelected [(n, some n)] n = true := by
  simp [cutSelected]

private def splitByteRecords (data : ByteArray) (delim : UInt8) : List ByteArray := Id.run do
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

private def splitBytesOn (data : ByteArray) (delim : UInt8) : List ByteArray := Id.run do
  let mut parts : List ByteArray := []
  let mut current := ByteArray.empty
  for byte in data do
    if byte == delim then
      parts := parts ++ [current]
      current := ByteArray.empty
    else
      current := current.push byte
  return parts ++ [current]

/-- Split a record into characters, each keeping its original bytes.
Invalid UTF-8 falls back to one byte per character, like the C locale. -/
private def charUnits (record : ByteArray) : List ByteArray :=
  match String.fromUTF8? record with
  | some s => s.toList.map (fun c => (String.singleton c).toUTF8)
  | none => record.toList.map (fun b => ByteArray.mk #[b])

private structure CutOptions where
  mode : Option CutMode := none
  ranges : List CutRange := []
  -- `none` for the empty delimiter, which never occurs in a line.
  delimiter : Option UInt8 := some 9
  outputDelimiter : Option ByteArray := none
  onlyDelimited : Bool := false
  complement : Bool := false
  zero : Bool := false
  files : List String := []

private def processRecord (opts : CutOptions) (record : ByteArray) :
    Option ByteArray :=
  let picked (i : Nat) : Bool :=
    if opts.complement then !cutSelected opts.ranges i else cutSelected opts.ranges i
  match opts.mode with
  | some .fields =>
      if opts.delimiter.all (fun d => !record.toList.contains d) then
        if opts.onlyDelimited then none else some record
      else
        let parts := splitBytesOn record (opts.delimiter.getD 9)
        let chosen := parts.zipIdx.filterMap fun (part, i) =>
          if picked (i + 1) then some part else none
        let joiner := opts.outputDelimiter.getD (ByteArray.mk #[opts.delimiter.getD 9])
        some (chosen.zipIdx.foldl (fun acc (part, i) =>
          if i == 0 then part else acc ++ joiner ++ part) ByteArray.empty)
  | some .bytes =>
      let units := record.toList.map (fun b => ByteArray.mk #[b])
      some (units.zipIdx.foldl (fun acc (unit, i) =>
        if picked (i + 1) then acc ++ unit else acc) ByteArray.empty)
  | _ =>
      let units := charUnits record
      some (units.zipIdx.foldl (fun acc (unit, i) =>
        if picked (i + 1) then acc ++ unit else acc) ByteArray.empty)

/-- `cut OPTION... [FILE]...`: print selected bytes, characters, or fields. -/
def runCut : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "cut OPTION... [FILE]..." args then
    return code
  let mut opts : CutOptions := {}
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
      let needValue : IO (Option String) := do
        match value with
        | some v => return some v
        | none =>
            match arr[i]? with
            | some v => return some v
            | none =>
                reportError prog s!"option '{name}' requires an argument"
                IO.eprintln tryMsg
                return none
      match name with
      | "--bytes" | "--characters" | "--fields" =>
          match ← needValue with
          | none => return exitFail
          | some spec =>
              if value.isNone then i := i + 1
              if opts.mode.isSome then
                reportError prog "only one list may be specified"
                IO.eprintln tryMsg
                return exitFail
              let fields := name == "--fields"
              match parseCutList fields spec with
              | .error msg =>
                  reportError prog msg
                  IO.eprintln tryMsg
                  return exitFail
              | .ok ranges =>
                  let mode := if name == "--bytes" then CutMode.bytes
                    else if fields then CutMode.fields else CutMode.chars
                  opts := { opts with mode := some mode, ranges := ranges }
      | "--delimiter" =>
          match ← needValue with
          | none => return exitFail
          | some v =>
              if value.isNone then i := i + 1
              if v.isEmpty then
                opts := { opts with delimiter := none }
              else if v.toList.length == 1 && v.toUTF8.size == 1 then
                opts := { opts with delimiter := some (v.toUTF8.data.getD 0 9) }
              else
                reportError prog "the delimiter must be a single character"
                IO.eprintln tryMsg
                return exitFail
      | "--output-delimiter" =>
          match ← needValue with
          | none => return exitFail
          | some v =>
              if value.isNone then i := i + 1
              opts := { opts with outputDelimiter := some v.toUTF8 }
      | "--only-delimited" => opts := { opts with onlyDelimited := true }
      | "--complement" => opts := { opts with complement := true }
      | "--zero-terminated" => opts := { opts with zero := true }
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
        | 's' => opts := { opts with onlyDelimited := true }
        | 'n' => pure ()
        | 'z' => opts := { opts with zero := true }
        | 'b' | 'c' | 'f' | 'd' =>
            let rest := String.ofList (chars.drop j)
            let value ←
              if !rest.isEmpty then pure rest
              else match arr[i]? with
                | some v => consumedNext := true; pure v
                | none =>
                    reportError prog s!"option requires an argument -- '{c}'"
                    IO.eprintln tryMsg
                    return exitFail
            if c == 'd' then
              if value.isEmpty then
                opts := { opts with delimiter := none }
              else if value.toList.length == 1 && value.toUTF8.size == 1 then
                opts := { opts with delimiter := some (value.toUTF8.data.getD 0 9) }
              else
                reportError prog "the delimiter must be a single character"
                IO.eprintln tryMsg
                return exitFail
            else
              if opts.mode.isSome then
                reportError prog "only one list may be specified"
                IO.eprintln tryMsg
                return exitFail
              let fields := c == 'f'
              match parseCutList fields value with
              | .error msg =>
                  reportError prog msg
                  IO.eprintln tryMsg
                  return exitFail
              | .ok ranges =>
                  let mode := if c == 'b' then CutMode.bytes
                    else if fields then CutMode.fields else CutMode.chars
                  opts := { opts with mode := some mode, ranges := ranges }
            j := chars.length
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            IO.eprintln tryMsg
            return exitFail
      if consumedNext then i := i + 1
  if opts.mode.isNone then
    reportError prog "you must specify a list of bytes, characters, or fields"
    IO.eprintln tryMsg
    return exitFail
  let delim : UInt8 := if opts.zero then 0 else 10
  let mut status := exitOk
  for file in operandsOrStdin opts.files do
    try
      let data ← readOperandBytes file
      let mut out := ByteArray.empty
      for record in splitByteRecords data delim do
        match processRecord opts record with
        | some line => out := out ++ line ++ ByteArray.mk #[delim]
        | none => pure ()
      writeStdout out
    catch e =>
      if isBrokenPipe e then return exitOk
      reportFileError prog file e
      status := exitFail
  return status

/-- Multicall registration for `cut`. -/
abbrev CutApplet := AppletTag "cut" runCut

end Lutils