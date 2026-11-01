/- Bounded, pure expansion of tab characters. -/
import Lutils.Shared.Common
import Lutils.Shared.UnicodeWidth

namespace Lutils

/-- A tab period cannot be zero. -/
structure TabWidth where
  value : Nat
  positive : 0 < value

def TabWidth.eight : TabWidth := ⟨8, by decide⟩

/-- The next multiple of a positive period is strictly after the column. -/
def TabWidth.next (width : TabWidth) (column : Nat) : Nat :=
  column + (width.value - column % width.value)

theorem TabWidth.next_gt (width : TabWidth) (column : Nat) :
    column < width.next column := by
  unfold TabWidth.next
  have h := Nat.mod_lt column width.positive
  omega

/-- Explicit stops may end, or continue at an absolute or relative period. -/
inductive TabRepeat where
  | absolute (width : TabWidth)
  | relative (width : TabWidth)

inductive ExpandStops where
  | periodic (width : TabWidth)
  | listed (stops : Array Nat) (continuation : Option TabRepeat)

/-- The column after an expanded tab. Explicit lists beyond their last stop
use one space when no continuation is present. -/
def ExpandStops.next (stops : ExpandStops) (column : Nat) : Nat :=
  match stops with
  | .periodic width => width.next column
  | .listed values continuation =>
      match values.find? (· > column) with
      | some stop => stop
      | none =>
          match continuation with
          | none => column + 1
          | some (.absolute width) => width.next column
          | some (.relative width) =>
              let origin := values.back?.getD 0
              origin + width.next (column - origin)

theorem ExpandStops.periodic_next_gt (width : TabWidth) (column : Nat) :
    column < (ExpandStops.periodic width).next column :=
  width.next_gt column

structure ExpandOptions where
  stops : ExpandStops := .periodic TabWidth.eight
  initialOnly : Bool := false
  files : List String := []

private def parseTabWidth (value : String) : Except String TabWidth :=
  match value.toNat? with
  | some n => if h : 0 < n then .ok ⟨n, h⟩
              else .error "tab size cannot be 0"
  | none => .error s!"invalid tab size: '{value}'"

/-- A pure parser for positive, strictly increasing stop columns. -/
def parseExpandStops (value : String) : Except String ExpandStops := do
  let tokens := (value.splitToList fun c => c == ',' || c == ' ' || c == '\t').filter (!·.isEmpty)
  if tokens.isEmpty then return .periodic TabWidth.eight
  let mut fixed : Array Nat := #[]
  let mut continuation : Option TabRepeat := none
  for token in tokens do
    if continuation.isSome then throw s!"invalid tab stops: '{value}'"
    if token.startsWith "/" || token.startsWith "+" then
      let width ← parseTabWidth (String.ofList (token.toList.drop 1))
      continuation := some (if token.startsWith "/" then .absolute width else .relative width)
    else
      let width ← parseTabWidth token
      if let some previous := fixed.back? then
        if width.value ≤ previous then throw "tab sizes must be ascending"
      fixed := fixed.push width.value
  if fixed.size == 1 && continuation.isNone then
    let width ← parseTabWidth (toString (fixed[0]!))
    return .periodic width
  return .listed fixed continuation

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

/-- Minimal UTF-8 decoder state carried across input chunks. -/
structure ExpandUtf8 where
  remaining : Nat := 0
  value : Nat := 0
  minimum : Nat := 0
  seen : Nat := 0

/-- Width of a Unicode scalar under the C.UTF-8 display rules. -/
def expandScalarWidth (scalar : Nat) : Nat := unicodeScalarCells scalar

/-- The transducer state is independent of its input buffer size. -/
structure ExpandState where
  column : Nat := 0
  initial : Bool := true
  utf8 : ExpandUtf8 := {}

private def expandAdvanceScalar (state : ExpandState) (byte : UInt8)
    (unicode : Bool) : ExpandState := Id.run do
  if !unicode || byte.toNat < 128 then
    return { state with column := state.column + state.utf8.seen + 1, utf8 := {} }
  let b := byte.toNat
  if state.utf8.remaining > 0 && 128 ≤ b && b < 192 then
    let scalar := state.utf8.value * 64 + b % 64
    if state.utf8.remaining > 1 then
      let decoder : ExpandUtf8 :=
        { remaining := state.utf8.remaining - 1, value := scalar,
          minimum := state.utf8.minimum, seen := state.utf8.seen + 1 }
      return { state with utf8 := decoder }
    if scalar ≥ state.utf8.minimum && scalar ≤ 0x10ffff &&
        !(0xd800 ≤ scalar && scalar ≤ 0xdfff) then
      let width := expandScalarWidth scalar
      return { state with column := state.column + width - 1, utf8 := {} }
    return { state with column := state.column + state.utf8.seen + 1, utf8 := {} }
  if 194 ≤ b && b ≤ 223 then
    let decoder : ExpandUtf8 := { remaining := 1, value := b % 32, minimum := 128 }
    return { state with column := state.column + state.utf8.seen + 1, utf8 := decoder }
  if 224 ≤ b && b ≤ 239 then
    let decoder : ExpandUtf8 := { remaining := 2, value := b % 16, minimum := 2048 }
    return { state with column := state.column + state.utf8.seen + 1, utf8 := decoder }
  if 240 ≤ b && b ≤ 244 then
    let decoder : ExpandUtf8 := { remaining := 3, value := b % 8, minimum := 65536 }
    return { state with column := state.column + state.utf8.seen + 1, utf8 := decoder }
  return { state with column := state.column + state.utf8.seen + 1, utf8 := {} }

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
  let all ← IO.getEnv "LC_ALL"
  let ctype ← IO.getEnv "LC_CTYPE"
  let lang ← IO.getEnv "LANG"
  let locale := (([all, ctype, lang] : List (Option String)).filterMap id).find? (!·.isEmpty)
    |>.getD "C"
  let unicode := locale != "C" && locale != "POSIX"
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
