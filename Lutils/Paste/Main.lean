/- Streaming, byte-preserving columns and serial records. -/
import Lutils.Shared.DelimitedReader

namespace Lutils

/-- A delimiter is either one byte or no byte (`\\0` in a delimiter list). -/
abbrev PasteDelimiter := Option UInt8

/-- Cycling delimiters always have at least one element. -/
structure PasteDelimiters where
  bytes : Array PasteDelimiter
  nonempty : 0 < bytes.size

def PasteDelimiters.default : PasteDelimiters := ⟨#[some 9], by decide⟩

/-- The delimiter at a column boundary, counted from zero. -/
def PasteDelimiters.at (ds : PasteDelimiters) (index : Nat) : PasteDelimiter :=
  ds.bytes[index % ds.bytes.size]'(Nat.mod_lt _ ds.nonempty)

/-- Cycling by a whole list leaves the selected delimiter unchanged. -/
theorem PasteDelimiters.at_cycle (ds : PasteDelimiters) (index : Nat) :
    ds.at (index + ds.bytes.size) = ds.at index := by
  simp [PasteDelimiters.at, Nat.add_mod_right]

inductive PasteMode where
  | parallel | serial
  deriving BEq

structure PasteOptions where
  mode : PasteMode := .parallel
  delimiters : PasteDelimiters := PasteDelimiters.default
  terminator : UInt8 := 10
  files : List String := []

/-- Interpret GNU delimiter escapes over bytes, preserving arbitrary UTF-8. -/
def pasteParseDelimiters (value : String) : Except String PasteDelimiters := Id.run do
  let input := value.toUTF8
  let mut items : Array PasteDelimiter := #[]
  let mut i := 0
  while i < input.size do
    if h : i < input.size then
     let c := input[i]'h
     if c == 92 && !(i + 1 < input.size) then
       return .error s!"delimiter list ends with an unescaped backslash: {value}"
     if hnext : c == 92 && i + 1 < input.size then
      have hbound : i + 1 < input.size := by
        simp only [Bool.and_eq_true] at hnext
        exact of_decide_eq_true hnext.2
      let escaped := input[i + 1]'hbound
      let byte := match escaped.toNat with
        | 48 => none
        | 110 => some 10
        | 116 => some 9
        | 114 => some 13
        | 98 => some 8
        | 102 => some 12
        | 118 => some 11
        | 92 => some 92
        | _ => some escaped
      items := items.push byte
      i := i + 2
     else
       items := items.push (some c)
       i := i + 1
  if h : 0 < items.size then return .ok ⟨items, h⟩
  return .ok ⟨#[none], by decide⟩

private def pasteParse (args : List String) : Except String PasteOptions :=
  go {} false args
where
  go (opts : PasteOptions) (literal : Bool) : List String → Except String PasteOptions
    | [] => .ok opts
    | arg :: rest =>
      if literal then go { opts with files := opts.files ++ [arg] } true rest
      else if arg == "--" then go opts true rest
      else if arg == "-" || !arg.startsWith "-" then
        go { opts with files := opts.files ++ [arg] } false rest
      else if arg == "--serial" then go { opts with mode := .serial } false rest
      else if arg == "--zero-terminated" then go { opts with terminator := 0 } false rest
      else if arg == "--delimiters" || arg == "-d" then
        match rest with
        | [] => .error s!"option '{arg}' requires an argument"
        | value :: tail =>
            (pasteParseDelimiters value).bind fun ds =>
              go { opts with delimiters := ds } false tail
      else if arg.startsWith "--delimiters=" then
        let value := (arg.drop "--delimiters=".length).toString
        (pasteParseDelimiters value).bind fun ds =>
          go { opts with delimiters := ds } false rest
      else if arg.startsWith "--" then .error s!"unrecognized option '{arg}'"
      else if arg.endsWith "d" then
        match short opts ((arg.drop 1).toString.toList.dropLast) with
        | .error message => .error message
        | .ok next =>
            match rest with
            | [] => .error "option requires an argument -- 'd'"
            | value :: tail =>
                (pasteParseDelimiters value).bind fun ds =>
                  go { next with delimiters := ds } false tail
      else
        match short opts (arg.drop 1).toString.toList with
        | .ok next => go next false rest
        | .error message => .error message
  short (opts : PasteOptions) : List Char → Except String PasteOptions
    | [] => .ok opts
    | 's' :: tail => short { opts with mode := .serial } tail
    | 'z' :: tail => short { opts with terminator := 0 } tail
    | 'd' :: tail =>
        (pasteParseDelimiters (String.ofList tail)).map fun ds =>
          { opts with delimiters := ds }
    | c :: _ => .error s!"invalid option -- '{c}'"

/-- Append an optional delimiter without allocating an intermediate array. -/
def PasteDelimiter.append (delimiter : PasteDelimiter) (output : ByteArray) : ByteArray :=
  match delimiter with
  | none => output
  | some byte => output.push byte

theorem PasteDelimiter.append_none (output : ByteArray) :
    PasteDelimiter.append none output = output := rfl

/-- One parallel output row. Missing cells still occupy their column. -/
def pasteRow (delimiters : PasteDelimiters) (terminator : UInt8)
    (records : Array (Option DelimitedRecord)) (output : ByteArray) : ByteArray := Id.run do
  let mut result := output
  for h : i in [:records.size] do
    if i > 0 then result := (delimiters.at (i - 1)).append result
    if let some record := records[i]'h.2.1 then
      result := result.fastAppend record.bytes
  return result.push terminator

/-- A missing cell contributes no bytes of its own. -/
theorem pasteRow_single (ds : PasteDelimiters) (term : UInt8)
    (record : DelimitedRecord) (out : ByteArray) :
    pasteRow ds term #[some record] out = (out.fastAppend record.bytes).push term := by
  simp [pasteRow]

structure PasteSource where
  path : String
  reader : DelimitedReader

private def pasteOpen (path : String) (terminator : UInt8) (chunkSize : USize) :
    IO PasteSource := do
  let handle ← if path == "-" then IO.getStdin
    else IO.FS.Stream.ofHandle <$> IO.FS.Handle.mk path .read
  return { path := path, reader := { handle := handle, terminator := terminator,
                                     chunkSize := chunkSize } }

private def pasteReportFileError (prog path : String) (error : IO.Error) : IO Unit :=
  match error with
  | .inappropriateType _ 21 _ => reportError prog s!"{path}: Is a directory"
  | _ => reportFileError prog path error

private def pasteSerial (source : PasteSource) (opts : PasteOptions)
    (output : IO.FS.Stream) : IO Unit := do
  let mut reader := source.reader
  let mut buffer := ByteArray.empty
  let mut count := 0
  repeat
    let (next, record) ← reader.next
    reader := next
    let some record := record | break
    if count > 0 then buffer := (opts.delimiters.at (count - 1)).append buffer
    buffer := buffer.fastAppend record.bytes
    count := count + 1
    if buffer.size >= 64 * 1024 then
      output.write buffer
      buffer := ByteArray.empty
  buffer := buffer.push opts.terminator
  output.write buffer

private def pasteParallel (initial : Array PasteSource) (opts : PasteOptions)
    (prog : String) (output : IO.FS.Stream) : IO Bool := do
  let mut sources := initial
  let mut buffer := ByteArray.empty
  let mut failed := false
  repeat
    let mut records : Array (Option DelimitedRecord) := #[]
    let mut nextSources : Array PasteSource := #[]
    for h : i in [:sources.size] do
      let source := sources[i]'h.2.1
      let (reader, record) ← try source.reader.next catch error => do
        pasteReportFileError prog source.path error
        failed := true
        let oldReader := source.reader
        let endedReader : DelimitedReader :=
          { handle := oldReader.handle, ended := true,
            terminator := oldReader.terminator, chunkSize := oldReader.chunkSize }
        pure (endedReader, none)
      nextSources := nextSources.push { source with reader := reader }
      records := records.push record
    sources := nextSources
    if !records.any Option.isSome then break
    buffer := pasteRow opts.delimiters opts.terminator records buffer
    if buffer.size >= 64 * 1024 then
      output.write buffer
      buffer := ByteArray.empty
  if !buffer.isEmpty then output.write buffer
  return failed

/-- `paste [OPTION]... [FILE]...`: stream records with bounded input and output. -/
def runPaste : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "paste [OPTION]... [FILE]..." args then
    return code
  let opts ← match pasteParse args with
    | .ok opts => pure opts
    | .error message =>
        reportError prog message
        return exitFail
  let paths := if opts.files.isEmpty then ["-"] else opts.files
  let repeatedStdin := (paths.filter (· == "-")).length > 1
  let chunkSize := if repeatedStdin then 1 else 64 * 1024
  let output ← IO.getStdout
  let mut failed := false
  match opts.mode with
  | .serial =>
      for path in paths do
        let source? ←
          try some <$> pasteOpen path opts.terminator chunkSize
          catch error => do
            pasteReportFileError prog path error
            failed := true
            pure none
        if let some source := source? then
          try pasteSerial source opts output
          catch error => do
            pasteReportFileError prog path error
            output.write (ByteArray.mk #[opts.terminator])
            failed := true
  | .parallel =>
      let mut sources : Array PasteSource := #[]
      for path in paths do
        try
          let source ← pasteOpen path opts.terminator chunkSize
          sources := sources.push source
        catch error =>
          pasteReportFileError prog path error
          failed := true
      if !failed && !sources.isEmpty then
        if ← pasteParallel sources opts prog output then failed := true
  output.flush
  return if failed then exitFail else exitOk

end Lutils
