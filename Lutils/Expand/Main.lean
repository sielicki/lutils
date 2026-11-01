/- Bounded, pure expansion of tab characters. -/
import Lutils.Shared.Common
import Lutils.Shared.TabColumns
import Lutils.Shared.TabStops

namespace Lutils

structure ExpandOptions where
  stops : ExpandStops := .periodic TabWidth.eight
  initialOnly : Bool := false
  files : List String := []

private def expandParse (args : List String) : Except String ExpandOptions :=
  go {} false args
where
  go (opts : ExpandOptions) (literal : Bool) : List String → Except String ExpandOptions
    | [] => .ok opts
    | arg :: rest =>
      if literal then go { opts with files := opts.files ++ [arg] } true rest
      else if arg == "--" then go opts true rest
      else if arg == "-" || !arg.startsWith "-" then
        go { opts with files := opts.files ++ [arg] } false rest
      else if arg == "--initial" then go { opts with initialOnly := true } false rest
      else if arg == "--tabs" || arg == "-t" then
        match rest with
        | [] => .error s!"option '{arg}' requires an argument"
        | value :: tail =>
            (parseExpandStops value).bind fun stops =>
              go { opts with stops := stops } false tail
      else if arg.startsWith "--tabs=" then
        (parseExpandStops (arg.drop "--tabs=".length).toString).bind fun stops =>
          go { opts with stops := stops } false rest
      else if arg.startsWith "--" then .error s!"unrecognized option '{arg}'"
      else if arg.toList.length > 1 && (arg.toList[1]!).isDigit then
        (parseExpandStops (arg.drop 1).toString).bind fun stops =>
          go { opts with stops := stops } false rest
      else
        match short opts (arg.drop 1).toString.toList with
        | .ok next => go next false rest
        | .error message => .error message
  short (opts : ExpandOptions) : List Char → Except String ExpandOptions
    | [] => .ok opts
    | 'i' :: tail => short { opts with initialOnly := true } tail
    | 't' :: tail => (parseExpandStops (String.ofList tail)).map fun stops =>
        { opts with stops := stops }
    | c :: _ => .error s!"invalid option -- '{c}'"

/-- Expansion state keeps leading-blank status apart from display columns. -/
structure ExpandState where
  column : Nat := 0
  initial : Bool := true
  utf8 : TabUtf8 := {}

private def expandAdvanceScalar (state : ExpandState) (byte : UInt8)
    (unicode : Bool) : ExpandState :=
  let next := (TabColumnState.advance ⟨state.column, state.utf8⟩ byte unicode)
  { state with column := next.column, utf8 := next.utf8 }

/-- Expand one bounded chunk without decoding or changing its output bytes. -/
def expandChunk (opts : ExpandOptions) (unicode : Bool)
    (state : ExpandState) (input : ByteArray) : ExpandState × ByteArray := Id.run do
  let mut current := state
  let mut output := ByteArray.empty
  for h : i in [:input.size] do
    let byte := input[i]'h.2.1
    if byte == 10 then
      output := output.push byte
      current := { column := 0, initial := true }
    else if byte == 9 then
      let column := current.column + current.utf8.seen
      let next := opts.stops.next column
      if !opts.initialOnly || current.initial then
        for _ in [:next - column] do output := output.push 32
      else output := output.push byte
      current := { current with column := next, utf8 := {} }
    else
      output := output.push byte
      if byte == 8 then
        current := { column := current.column + current.utf8.seen - 1, initial := false }
      else if byte == 0 then
        current := { current with column := current.column + current.utf8.seen, initial := false, utf8 := {} }
      else
        current := expandAdvanceScalar current byte unicode
        if byte != 32 then current := { current with initial := false }
  return (current, output)

/-- An empty chunk does not change the column or emit bytes. -/
theorem expandChunk_empty (opts : ExpandOptions) (unicode : Bool)
    (state : ExpandState) : expandChunk opts unicode state ByteArray.empty =
      (state, ByteArray.empty) := by simp [expandChunk]

/-- `expand [OPTION]... [FILE]...`: pure chunk transformation over bounded I/O. -/
def runExpand : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "expand [OPTION]... [FILE]..." args then
    return code
  let opts ← match expandParse args with
    | .ok value => pure value
    | .error message => reportError prog message; return exitFail
  let unicode ← tabUnicodeLocale
  let paths := if opts.files.isEmpty then ["-"] else opts.files
  let mut failed := false
  let chunk : ByteChunkSize := ⟨64 * 1024, by native_decide⟩
  for path in paths do
    try
      let transducer : ByteStreamTransducer ExpandState Unit :=
        { initial := {}
          step := expandChunk opts unicode
          finish := fun _ => (ByteArray.empty, ()) }
      discard <| runByteStream path chunk transducer
    catch error =>
      reportFileError prog path error
      failed := true
  return if failed then exitFail else exitOk

end Lutils
