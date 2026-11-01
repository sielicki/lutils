/- Compare two sorted byte streams, preserving their records exactly. -/
import Lutils.Shared.DelimitedReader

namespace Lutils

/-- Records shared by line-oriented utilities, viewed by the comm merge. -/
abbrev CommRecord := DelimitedRecord

/-- Each merge step consumes a record from one or both inputs. -/
inductive CommColumn where
  | first | second | common
  deriving BEq, DecidableEq

/-- Lexicographic ordering of raw records in the C and C.UTF-8 locales. -/
def commCompare (left right : CommRecord) : Ordering := Id.run do
  let size := min left.bytes.size right.bytes.size
  for h : i in [:size] do
    have hi : i < size := h.2.1
    let a := left.bytes[i]'(by dsimp [size] at hi; omega)
    let b := right.bytes[i]'(by dsimp [size] at hi; omega)
    if a < b then return .lt
    if a > b then return .gt
  return compare left.bytes.size right.bytes.size

/-- Decide which input head to consume. -/
def commChoose (left right : Option CommRecord) : Option CommColumn :=
  match left, right with
  | none, none => none
  | some _, none => some .first
  | none, some _ => some .second
  | some a, some b =>
      match commCompare a b with
      | .lt => some .first
      | .gt => some .second
      | .eq => some .common

/-- A merge step exists whenever either input has a head. -/
theorem commChoose_progress (left right : Option CommRecord)
    (h : left.isSome || right.isSome) : (commChoose left right).isSome := by
  cases left with
  | none =>
      cases right with
      | none => simp at h
      | some _ => rfl
  | some a =>
      cases right with
      | none => rfl
      | some b => cases hcmp : commCompare a b <;> simp [commChoose, hcmp]

/-- Visibility is independent of the order of suppression flags. -/
structure CommVisibility where
  first : Bool := true
  second : Bool := true
  common : Bool := true

def CommVisibility.shows (v : CommVisibility) : CommColumn → Bool
  | .first => v.first
  | .second => v.second
  | .common => v.common

/-- The number of separators preceding a visible column. -/
def CommVisibility.prefixCount (v : CommVisibility) : CommColumn → Nat
  | .first => 0
  | .second => if v.first then 1 else 0
  | .common => (if v.first then 1 else 0) + (if v.second then 1 else 0)

theorem CommVisibility.prefixCount_le_two (v : CommVisibility) (column : CommColumn) :
    v.prefixCount column ≤ 2 := by
  cases v with
  | mk first second common =>
      cases first <;> cases second <;> cases column <;>
        simp [CommVisibility.prefixCount]

inductive CommOrderPolicy where
  | default | check | ignore
  deriving BEq

structure CommOptions where
  visibility : CommVisibility := {}
  order : CommOrderPolicy := .default
  delimiter : ByteArray := "\t".toUTF8
  delimiterExplicit : Bool := false
  terminator : UInt8 := 10
  total : Bool := false
  files : List String := []

/-- Pure option parser; the command runner owns diagnostics and file effects. -/
private def commParse (args : List String) : Except String CommOptions :=
  go {} false args
where
  go (opts : CommOptions) (literal : Bool) : List String → Except String CommOptions
    | [] => .ok opts
    | arg :: rest =>
      if literal then go { opts with files := opts.files ++ [arg] } true rest
      else if arg == "--" then go opts true rest
      else if arg == "-" || !arg.startsWith "-" then
        go { opts with files := opts.files ++ [arg] } false rest
      else if arg == "--check-order" then go { opts with order := .check } false rest
      else if arg == "--nocheck-order" then go { opts with order := .ignore } false rest
      else if arg == "--zero-terminated" then go { opts with terminator := 0 } false rest
      else if arg == "--total" then go { opts with total := true } false rest
      else if arg == "--output-delimiter" then
        match rest with
        | [] => .error "option '--output-delimiter' requires an argument"
        | value :: tail =>
            let delimiter := if value.isEmpty then ByteArray.mk #[0] else value.toUTF8
            if opts.delimiterExplicit && opts.delimiter != delimiter then
              .error "multiple output delimiters specified"
            else go { opts with delimiter := delimiter, delimiterExplicit := true } false tail
      else if arg.startsWith "--output-delimiter=" then
        let value := (arg.drop "--output-delimiter=".length).toString
        let delimiter := if value.isEmpty then ByteArray.mk #[0] else value.toUTF8
        if opts.delimiterExplicit && opts.delimiter != delimiter then
          .error "multiple output delimiters specified"
        else go { opts with delimiter := delimiter, delimiterExplicit := true } false rest
      else if arg.startsWith "--" then .error s!"unrecognized option '{arg}'"
      else
        match applyShort opts (arg.drop 1).toString.toList with
        | .ok next => go next false rest
        | .error message => .error message
  applyShort (opts : CommOptions) : List Char → Except String CommOptions
    | [] => .ok opts
    | c :: rest =>
      let next : Except String CommOptions := match c with
        | '1' => .ok { opts with visibility := { opts.visibility with first := false } }
        | '2' => .ok { opts with visibility := { opts.visibility with second := false } }
        | '3' => .ok { opts with visibility := { opts.visibility with common := false } }
        | 'z' => .ok { opts with terminator := 0 }
        | _ => .error s!"invalid option -- '{c}'"
      next.bind (fun newOpts => applyShort newOpts rest)

/-- Append one selected record without decoding its bytes. -/
def commAppend (opts : CommOptions) (column : CommColumn)
    (record : CommRecord) (buffer : ByteArray) : ByteArray :=
  if !opts.visibility.shows column then buffer
  else Id.run do
    let mut out := buffer
    for _ in [:opts.visibility.prefixCount column] do
      out := out.fastAppend opts.delimiter
    out := out.fastAppend record.bytes
    return out.push opts.terminator

/-- Hiding a column leaves the output buffer unchanged. -/
theorem commAppend_hidden (opts : CommOptions) (column : CommColumn)
    (record : CommRecord) (buffer : ByteArray)
    (h : opts.visibility.shows column = false) :
    commAppend opts column record buffer = buffer := by
  simp [commAppend, h]

structure CommCounts where
  first : Nat := 0
  second : Nat := 0
  common : Nat := 0

def CommCounts.bump (counts : CommCounts) : CommColumn → CommCounts
  | .first => { counts with first := counts.first + 1 }
  | .second => { counts with second := counts.second + 1 }
  | .common => { counts with common := counts.common + 1 }

theorem CommCounts.bump_total (counts : CommCounts) (column : CommColumn) :
    let next := counts.bump column
    next.first + next.second + next.common =
      counts.first + counts.second + counts.common + 1 := by
  cases column <;> simp [CommCounts.bump] <;> omega

/-- A source retains the last two records for GNU's final order check at EOF. -/
structure CommSource where
  reader : DelimitedReader
  head : Option CommRecord := none
  previous : Option CommRecord := none
  warned : Bool := false

/-- Order checks are enabled immediately by `--check-order`, or after an
unpaired record has been found with the default policy. -/
def CommOrderPolicy.shouldCheck (policy : CommOrderPolicy) (seenUnique : Bool) : Bool :=
  policy == .check || (policy == .default && seenUnique)

/-- A record pair is inverted exactly when its successor sorts earlier. -/
def commInverted (previous current : Option CommRecord) : Bool :=
  match previous, current with
  | some a, some b => commCompare b a == .lt
  | _, _ => false

theorem commInverted_none_left (record : Option CommRecord) :
    commInverted none record = false := by
  cases record <;> rfl

def CommSource.advance (source : CommSource) (policy : CommOrderPolicy)
    (seenUnique : Bool) : IO (CommSource × Bool) := do
  let (reader, head) ← source.reader.next
  let inverted := if head.isSome then commInverted source.head head
    else commInverted source.previous source.head
  let diagnosed := !source.warned && policy.shouldCheck seenUnique && inverted
  return ({ reader := reader, head := head, previous := source.head,
            warned := source.warned || diagnosed }, diagnosed)

private def commOpen (path : String) (terminator : UInt8)
    (chunkSize : USize := 64 * 1024) : IO CommSource := do
  let handle ← if path == "-" then IO.getStdin
    else IO.FS.Stream.ofHandle <$> IO.FS.Handle.mk path .read
  return { reader := { handle := handle, terminator := terminator,
                       chunkSize := chunkSize } }

private def commTotal (opts : CommOptions) (counts : CommCounts) : ByteArray := Id.run do
  let mut output := (toString counts.first).toUTF8
  output := (output.fastAppend opts.delimiter).fastAppend (toString counts.second).toUTF8
  output := (output.fastAppend opts.delimiter).fastAppend (toString counts.common).toUTF8
  output := (output.fastAppend opts.delimiter).fastAppend "total".toUTF8
  return output.push opts.terminator

/-- `comm [OPTION]... FILE1 FILE2`: compare sorted records using bounded I/O. -/
def runComm : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "comm [OPTION]... FILE1 FILE2" args then
    return code
  let opts ← match commParse args with
    | .ok options => pure options
    | .error message =>
        reportError prog message
        return exitFail
  let (firstPath, secondPath) ← match opts.files with
    | [first, second] => pure (first, second)
    | _ =>
        reportError prog "exactly two input files are required"
        return exitFail
  -- Two stdin operands share one stream; read a byte at a time so neither
  -- source prefetches records belonging to the other.
  let chunkSize := if firstPath == "-" && secondPath == "-" then 1 else 64 * 1024
  let mut first ← try commOpen firstPath opts.terminator chunkSize catch error =>
    reportFileError prog firstPath error
    return exitFail
  let mut second ← try commOpen secondPath opts.terminator chunkSize catch error =>
    reportFileError prog secondPath error
    return exitFail
  (first, _) ← first.advance opts.order false
  (second, _) ← second.advance opts.order false
  let output ← IO.getStdout
  let mut outputBuffer := ByteArray.empty
  let mut counts : CommCounts := {}
  let mut sawUnique := false
  let mut stoppedForOrder := false
  let mut errorsRev : List Nat := []
  repeat
    let some column := commChoose first.head second.head | break
    let record := match column with
      | .first => first.head.getD ⟨ByteArray.empty⟩
      | .second => second.head.getD ⟨ByteArray.empty⟩
      | .common => first.head.getD ⟨ByteArray.empty⟩
    if column != .common then sawUnique := true
    counts := counts.bump column
    outputBuffer := commAppend opts column record outputBuffer
    if outputBuffer.size >= 64 * 1024 then
      output.write outputBuffer
      outputBuffer := ByteArray.empty
    match column with
    | .first =>
        let (next, diagnosed) ← first.advance opts.order sawUnique
        first := next
        if diagnosed then errorsRev := 1 :: errorsRev
    | .second =>
        let (next, diagnosed) ← second.advance opts.order sawUnique
        second := next
        if diagnosed then errorsRev := 2 :: errorsRev
    | .common =>
        let (nextFirst, firstDiagnosed) ← first.advance opts.order sawUnique
        first := nextFirst
        if firstDiagnosed then errorsRev := 1 :: errorsRev
        if opts.order != .check || !firstDiagnosed then
          let (nextSecond, secondDiagnosed) ← second.advance opts.order sawUnique
          second := nextSecond
          if secondDiagnosed then errorsRev := 2 :: errorsRev
    if opts.order == .check && !errorsRev.isEmpty then
      stoppedForOrder := true
      break
  if opts.total && !stoppedForOrder then
    outputBuffer := outputBuffer.fastAppend (commTotal opts counts)
  if !outputBuffer.isEmpty then output.write outputBuffer
  output.flush
  if !errorsRev.isEmpty then
    for number in errorsRev.reverse do
      reportError prog s!"file {number} is not in sorted order"
    if opts.order == .default then reportError prog "input is not in sorted order"
    return exitFail
  return exitOk

/-- Multicall registration for `comm`. -/
abbrev CommApplet := AppletTag "comm" runComm

end Lutils
