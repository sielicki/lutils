/- Pure streaming conversion of spaces to tabs. -/
import Lutils.Shared.Common
import Lutils.Shared.TabStops
import Lutils.Shared.TabColumns

namespace Lutils

/-- Conversion scope is explicit so `--first-only` can override `--all`. -/
inductive UnexpandScope where
  | leading
  | all
  deriving BEq, DecidableEq

structure UnexpandOptions where
  stops : ExpandStops := .periodic TabWidth.eight
  scope : UnexpandScope := .leading
  firstOnly : Bool := false
  files : List String := []

private def unexpandParse (args : List String) : Except String UnexpandOptions :=
  go {} false args
where
  go (opts : UnexpandOptions) (literal : Bool) : List String → Except String UnexpandOptions
    | [] => .ok opts
    | arg :: rest =>
      if literal then go { opts with files := opts.files ++ [arg] } true rest
      else if arg == "--" then go opts true rest
      else if arg == "-" || !arg.startsWith "-" then
        go { opts with files := opts.files ++ [arg] } false rest
      else if arg == "--all" then go { opts with scope := if opts.firstOnly then .leading else .all } false rest
      else if arg == "--first-only" then go { opts with scope := .leading, firstOnly := true } false rest
      else if arg == "--tabs" || arg == "-t" then
        match rest with
        | [] => .error s!"option '{arg}' requires an argument"
        | value :: tail =>
            (parseExpandStops value).bind fun stops =>
              go { opts with stops := stops, scope := if opts.firstOnly then .leading else .all } false tail
      else if arg.startsWith "--tabs=" then
        (parseExpandStops (arg.drop "--tabs=".length).toString).bind fun stops =>
          go { opts with stops := stops, scope := if opts.firstOnly then .leading else .all } false rest
      else if arg.startsWith "--" then .error s!"unrecognized option '{arg}'"
      else if arg.toList.length > 1 && (arg.toList[1]!).isDigit then
        (parseExpandStops (arg.drop 1).toString).bind fun stops =>
          go { opts with stops := stops, scope := if opts.firstOnly then .leading else .all } false rest
      else
        match short opts (arg.drop 1).toString.toList with
        | .ok next => go next false rest
        | .error message => .error message
  short (opts : UnexpandOptions) : List Char → Except String UnexpandOptions
    | [] => .ok opts
    | 'a' :: tail => short { opts with scope := if opts.firstOnly then .leading else .all } tail
    | 't' :: tail => (parseExpandStops (String.ofList tail)).map fun stops =>
        { opts with stops := stops, scope := if opts.firstOnly then .leading else .all }
    | c :: _ => .error s!"invalid option -- '{c}'"

/-- Pending spaces end at a tab stop or a nonblank byte. -/
structure UnexpandState where
  column : Nat := 0
  pending : Nat := 0
  leading : Bool := true
  utf8 : TabUtf8 := {}
  converted : Bool := false

private def appendSpaces (output : ByteArray) (count : Nat) : ByteArray := Id.run do
  let mut result := output
  for _ in [:count] do result := result.push 32
  return result

/-- A chunk transformation with pending space state independent of the chunk size. -/
def unexpandChunk (opts : UnexpandOptions) (unicode : Bool) (state : UnexpandState)
    (input : ByteArray) : UnexpandState × ByteArray := Id.run do
  let mut current := state
  let mut output := ByteArray.empty
  for h : i in [:input.size] do
    let byte := input[i]'h.2.1
    let convert := opts.scope == .all || current.leading
    if byte == 32 && convert then
      current := { current with column := current.column + current.utf8.seen, utf8 := {} }
      if !opts.stops.hasNext current.column then
        output := (appendSpaces output current.pending).push 32
        current := { current with column := current.column + 1, pending := 0, converted := false }
      else
        let next := opts.stops.next (current.column - current.pending)
        if current.pending > 0 && current.column == next then
          output := output.push 9
          current := { current with pending := 0, converted := true }
        let count := current.pending + 1
        let next := opts.stops.next (current.column - current.pending)
        if current.column + 1 == next && (count > 1 || current.column == 0) then
          output := output.push 9
          current := { current with column := current.column + 1, pending := 0, converted := true }
        else current := { current with column := current.column + 1, pending := count }
    else if byte == 9 then
      if !convert || !opts.stops.hasNext (current.column - current.pending) ||
          (current.pending == 1 && current.column == opts.stops.next (current.column - current.pending) &&
            !opts.stops.hasNext current.column) then
        output := appendSpaces output current.pending
      else if current.pending > 0 && current.column == opts.stops.next (current.column - current.pending) &&
          opts.stops.hasNext current.column then
        output := output.push 9
      output := output.push byte
      current := { current with column := opts.stops.next (current.column + current.utf8.seen), pending := 0, utf8 := {}, converted := true }
    else
      if current.pending == 1 && current.converted &&
          current.column == opts.stops.next (current.column - current.pending) &&
          opts.stops.hasNext current.column then
        output := output.push 9
      else output := appendSpaces output current.pending
      output := output.push byte
      if byte == 10 then current := {}
      else if byte == 8 then
        current := { column := current.column + current.utf8.seen - 1, leading := false }
      else if byte == 0 then
        current := { current with column := current.column + current.utf8.seen, pending := 0, leading := false, utf8 := {}, converted := false }
      else
        let next := (TabColumnState.advance ⟨current.column, current.utf8⟩ byte unicode)
        current := { column := next.column, leading := false, utf8 := next.utf8 }
  return (current, output)

theorem unexpandChunk_empty (opts : UnexpandOptions) (unicode : Bool)
    (state : UnexpandState) :
    unexpandChunk opts unicode state ByteArray.empty = (state, ByteArray.empty) := by
  simp [unexpandChunk]

/-- Flush a final partial blank run using the same tab-stop rule as a line end. -/
def unexpandFinish (opts : UnexpandOptions) (state : UnexpandState) : ByteArray :=
  if state.pending == 1 && state.converted &&
      state.column == opts.stops.next (state.column - state.pending) &&
      opts.stops.hasNext state.column then
    ByteArray.empty.push 9
  else appendSpaces ByteArray.empty state.pending

theorem unexpandFinish_noPending (opts : UnexpandOptions) (state : UnexpandState)
    (h : state.pending = 0) : unexpandFinish opts state = ByteArray.empty := by
  simp [unexpandFinish, h, appendSpaces]

def runUnexpand : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "unexpand [OPTION]... [FILE]..." args then
    return code
  let opts ← match unexpandParse args with
    | .ok value => pure value
    | .error message => reportError prog message; return exitFail
  let paths := operandsOrStdin opts.files
  let unicode ← tabUnicodeLocale
  let mut failed := false
  let chunk : ByteChunkSize := ⟨64 * 1024, by native_decide⟩
  for path in paths do
    try
      let transducer : ByteStreamTransducer UnexpandState Unit :=
        { initial := {}
          step := unexpandChunk opts unicode
          finish := fun state => (unexpandFinish opts state, ()) }
      discard <| runByteStream path chunk transducer
    catch error =>
      reportFileError prog path error
      failed := true
  return if failed then exitFail else exitOk

end Lutils
