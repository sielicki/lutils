/- Wc utility implementation. -/
import Lutils.Shared.Common
import Std.Tactic.BVDecide
import UnicodeBasic

namespace Lutils

/-- Counts for one input, in GNU print order (lines, words, chars, bytes, max). -/
structure WcCounts where
  lines : Nat := 0
  words : Nat := 0
  chars : Nat := 0
  bytes : Nat := 0
  maxLine : Nat := 0

/-- Output fields appear in this order, regardless of option order. -/
inductive WcColumn where
  | lines
  | words
  | chars
  | bytes
  | maxLine
  deriving BEq

def WcColumn.value (column : WcColumn) (counts : WcCounts) : Nat :=
  match column with
  | .lines => counts.lines
  | .words => counts.words
  | .chars => counts.chars
  | .bytes => counts.bytes
  | .maxLine => counts.maxLine

def wcLongColumn? : String → Option WcColumn
  | "--lines" => some .lines
  | "--words" => some .words
  | "--chars" => some .chars
  | "--bytes" => some .bytes
  | "--max-line-length" => some .maxLine
  | _ => none

def wcShortColumn? : Char → Option WcColumn
  | 'l' => some .lines
  | 'w' => some .words
  | 'm' => some .chars
  | 'c' => some .bytes
  | 'L' => some .maxLine
  | _ => none

/-- Count newlines directly over bytes, without building a list or decoding text. -/
private def wcNewlineStep (count : Nat) (byte : UInt8) : Nat :=
  if byte == 10 then count + 1 else count

def wcNewlineCount (data : ByteArray) : Nat :=
  data.data.foldl wcNewlineStep 0

private theorem wcCountFold (bytes : List UInt8) (start : Nat) :
    bytes.foldl wcNewlineStep start =
      start + bytes.count (10 : UInt8) := by
  induction bytes generalizing start with
  | nil => simp
  | cons byte rest ih =>
      by_cases h : byte = 10
      · simp [wcNewlineStep, h, ih]; omega
      · simp [wcNewlineStep, h, ih]

/-- The allocation-free fold counts exactly the newlines in the backing array. -/
theorem wcNewlineCount_eq_count (data : ByteArray) :
    wcNewlineCount data = data.data.toList.count (10 : UInt8) := by
  rw [wcNewlineCount, ← Array.foldl_toList]
  simpa using wcCountFold data.data.toList 0

/-- The counts needed when only `-l` and/or `-c` are requested. -/
def wcByteCounts (data : ByteArray) : WcCounts :=
  { lines := wcNewlineCount data, bytes := data.size }

def wcCounts (data : ByteArray) : WcCounts :=
  let text := decodeLossy data
  let (lines, _) := linesOf text
  { (wcByteCounts data) with
    words := (wordsOf text).length
    chars := text.length
    maxLine := lines.foldl (fun m l => max m l.length) 0 }

/-- The fast path agrees with the full path on every field it computes. -/
theorem wcByteCounts_lines_eq (data : ByteArray) :
    (wcByteCounts data).lines = (wcCounts data).lines := by
  rfl

theorem wcByteCounts_bytes_eq (data : ByteArray) :
    (wcByteCounts data).bytes = (wcCounts data).bytes := by
  rfl

theorem wcByteCounts_value_eq (data : ByteArray) (column : WcColumn)
    (h : column = .lines ∨ column = .bytes) :
    column.value (wcByteCounts data) = column.value (wcCounts data) := by
  rcases h with h | h <;> cases h <;> rfl

theorem wcByteCounts_columns_eq (data : ByteArray) (columns : List WcColumn)
    (h : ∀ column ∈ columns, column = .lines ∨ column = .bytes) :
    columns.map (·.value (wcByteCounts data)) =
      columns.map (·.value (wcCounts data)) := by
  apply List.map_congr_left
  intro column hc
  exact wcByteCounts_value_eq data column (h column hc)

/-- The byte-level counts needed by the common `wc` modes. -/
inductive WcScanMode where
  | bytes | lines | words | linesAndWords
  deriving BEq, DecidableEq

structure WcScanState where
  lines : Nat := 0
  words : Nat := 0
  bytes : Nat := 0
  inWord : Bool := false

/-- GNU's byte-locale word separators include the single-byte no-break space. -/
@[inline] private def wcSpace (byte : UInt8) : Bool :=
  byte == 32 || byte == 160 || (byte >= 9 && byte <= 13)

theorem wcSpace_exact (byte : UInt8) :
    wcSpace byte = (byte == 32 || byte == 160 || byte == 9 || byte == 10 || byte == 11 ||
      byte == 12 || byte == 13) := by
  unfold wcSpace
  bv_decide

/-- Scan one bounded input chunk. The mode is selected once per chunk. -/
def wcScanChunk (mode : WcScanMode) (state : WcScanState)
    (input : ByteArray) : WcScanState := Id.run do
  let mut lines := state.lines
  let mut words := state.words
  let mut inWord := state.inWord
  match mode with
  | .bytes => pure ()
  | .lines =>
    for byte in input do
      if byte == 10 then lines := lines + 1
  | .words =>
    for byte in input do
      if wcSpace byte then inWord := false
      else if !inWord then
        words := words + 1
        inWord := true
  | .linesAndWords =>
    for byte in input do
      if byte == 10 then lines := lines + 1
      if wcSpace byte then inWord := false
      else if !inWord then
        words := words + 1
        inWord := true
  return { lines := lines, words := words, bytes := state.bytes + input.size, inWord := inWord }

theorem wcScanChunk_bytes (mode : WcScanMode) (state : WcScanState)
    (input : ByteArray) :
    (wcScanChunk mode state input).bytes = state.bytes + input.size := by
  cases mode <;> simp [wcScanChunk]

private def WcScanState.counts (state : WcScanState) : WcCounts :=
  { lines := state.lines, words := state.words, bytes := state.bytes }

private def wcScanFile (mode : WcScanMode) (file : String) : IO WcCounts := do
  let transducer : ByteStreamTransducer WcScanState WcCounts :=
    { initial := {}
      step := fun state input => (wcScanChunk mode state input, ByteArray.empty)
      finish := fun state => (ByteArray.empty, state.counts) }
  runByteStream file ByteChunkSize.fourMiB transducer

/-- The C locale treats non-ASCII bytes as non-printing; UTF-8 locales decode
complete scalar values before counting characters or measuring line width. -/
inductive WcLocale where
  | c | utf8
  deriving BEq, DecidableEq

private def wcLocale : IO WcLocale := do
  let all ← IO.getEnv "LC_ALL"
  let ctype ← IO.getEnv "LC_CTYPE"
  let lang ← IO.getEnv "LANG"
  let name := (([all, ctype, lang] : List (Option String)).filterMap id).find? (!·.isEmpty)
    |>.getD "C"
  return if name == "C" || name == "POSIX" then .c else .utf8

/-- State sufficient to decode a scalar value across any chunk boundary. -/
structure WcUtf8Decoder where
  remaining : Nat := 0
  value : Nat := 0
  minimum : Nat := 0

private def WcUtf8Decoder.start (byte : UInt8) : WcUtf8Decoder × Option Nat :=
  let b := byte.toNat
  if b < 128 then ({}, some b)
  else if b >= 194 && b <= 223 then ({ remaining := 1, value := b % 32, minimum := 128 }, none)
  else if b >= 224 && b <= 239 then ({ remaining := 2, value := b % 16, minimum := 2048 }, none)
  else if b >= 240 && b <= 244 then ({ remaining := 3, value := b % 8, minimum := 65536 }, none)
  else ({}, none)

/-- A malformed sequence is discarded; its first non-continuation byte is
processed as the start of the next sequence. -/
private def WcUtf8Decoder.feed (decoder : WcUtf8Decoder) (byte : UInt8) :
    WcUtf8Decoder × Option Nat :=
  if decoder.remaining == 0 then WcUtf8Decoder.start byte
  else if byte.toNat < 128 || byte.toNat >= 192 then WcUtf8Decoder.start byte
  else
    let value := decoder.value * 64 + byte.toNat % 64
    if decoder.remaining > 1 then
      ({ decoder with remaining := decoder.remaining - 1, value := value }, none)
    else if value >= decoder.minimum && value <= 0x10ffff &&
        !(value >= 0xd800 && value <= 0xdfff) then
      ({}, some value)
    else ({}, none)

private theorem wcUtf8Ascii (byte : UInt8) (h : byte.toNat < 128) :
    (WcUtf8Decoder.start byte).2 = some byte.toNat := by
  simp [WcUtf8Decoder.start, h]

/-- Whitespace recognized by `iswspace` in UTF-8 locales. -/
@[inline] private def wcUnicodeSpace (c : Nat) : Bool :=
  c == 32 || (c >= 9 && c <= 13) || c == 0xa0 ||
  c == 0x1680 || (c >= 0x2000 && c <= 0x200a) ||
  c == 0x2028 || c == 0x2029 || c == 0x202f || c == 0x205f || c == 0x3000

/-- Terminal cell width for printable Unicode scalar values. -/
private def wcUnicodeWidth (c : Nat) : Nat :=
  if c < 32 || (c >= 0x7f && c < 0xa0) then 0
  else if c < 0x7f then 1
  else if Unicode.GeneralCategory.isNonspacingMark (Char.ofNat c) ||
      Unicode.GeneralCategory.isEnclosingMark (Char.ofNat c) ||
      Unicode.GeneralCategory.isFormat (Char.ofNat c) then 0
  else if c >= 0x1100 && (
      c <= 0x115f || c == 0x2329 || c == 0x232a ||
      (c >= 0x2e80 && c <= 0xa4cf) ||
      (c >= 0xac00 && c <= 0xd7a3) ||
      (c >= 0xf900 && c <= 0xfaff) ||
      (c >= 0xfe10 && c <= 0xfe19) ||
      (c >= 0xfe30 && c <= 0xfe6f) ||
      (c >= 0xff00 && c <= 0xff60) ||
      (c >= 0xffe0 && c <= 0xffe6) ||
      (c >= 0x1f300 && c <= 0x1faff) ||
      (c >= 0x20000 && c <= 0x3fffd)) then 2
  else 1

private theorem wcUnicodeWidth_le_two (c : Nat) : wcUnicodeWidth c ≤ 2 := by
  unfold wcUnicodeWidth
  split
  · omega
  · split
    · omega
    · split
      · omega
      · split <;> omega

/-- The text scan keeps only a decoder, counters, and the current line width. -/
structure WcTextState where
  counts : WcCounts := {}
  column : Nat := 0
  inWord : Bool := false
  decoder : WcUtf8Decoder := {}

/-- Word-only UTF-8 scanning avoids character-width work on ASCII inputs. -/
structure WcUnicodeWordState where
  lines : Nat := 0
  words : Nat := 0
  bytes : Nat := 0
  inWord : Bool := false
  decoder : WcUtf8Decoder := {}

def wcUnicodeWordChunk (mode : WcScanMode) (state : WcUnicodeWordState)
    (input : ByteArray) : WcUnicodeWordState := Id.run do
  if input.data.all (fun byte => byte.toNat < 128) then
    let pendingWord := state.decoder.remaining > 0 && !state.inWord
    let scanned := wcScanChunk mode
      { lines := state.lines, words := state.words + if pendingWord then 1 else 0,
        bytes := state.bytes, inWord := state.inWord || pendingWord } input
    return { lines := scanned.lines, words := scanned.words, bytes := scanned.bytes,
             inWord := scanned.inWord }
  let mut lines := state.lines
  let mut words := state.words
  let mut inWord := state.inWord
  let mut decoder := state.decoder
  for byte in input do
    if byte.toNat < 128 then
      if decoder.remaining > 0 then
        if !inWord then
          words := words + 1
          inWord := true
        decoder := {}
      if byte == 10 then lines := lines + 1
      if wcSpace byte then inWord := false
      else if !inWord then
        words := words + 1
        inWord := true
    else
      if decoder.remaining > 0 && byte.toNat >= 192 && !inWord then
        words := words + 1
        inWord := true
      let (next, scalar) := decoder.feed byte
      decoder := next
      match scalar with
      | some c =>
          if wcUnicodeSpace c then inWord := false
          else if !inWord then
            words := words + 1
            inWord := true
      | none =>
          if decoder.remaining == 0 && !inWord then
            words := words + 1
            inWord := true
  return { lines := lines, words := words, bytes := state.bytes + input.size,
           inWord := inWord, decoder := decoder }

private def wcUnicodeWordFile (mode : WcScanMode) (file : String) : IO WcCounts := do
  let transducer : ByteStreamTransducer WcUnicodeWordState WcCounts :=
    { initial := {}
      step := fun state input => (wcUnicodeWordChunk mode state input, ByteArray.empty)
      finish := fun state => (ByteArray.empty,
        { lines := state.lines,
          words := state.words + if state.decoder.remaining > 0 && !state.inWord then 1 else 0,
          bytes := state.bytes }) }
  runByteStream file ByteChunkSize.fourMiB transducer

structure WcUnicodeCharState where
  chars : Nat := 0
  bytes : Nat := 0
  decoder : WcUtf8Decoder := {}

/-- ASCII chunks contribute one character per byte without decoding. -/
def wcUnicodeCharChunk (state : WcUnicodeCharState)
    (input : ByteArray) : WcUnicodeCharState := Id.run do
  if input.data.all (fun byte => byte.toNat < 128) then
    return { chars := state.chars + input.size, bytes := state.bytes + input.size }
  let mut chars := state.chars
  let mut decoder := state.decoder
  for byte in input do
    if byte.toNat < 128 then
      chars := chars + 1
      decoder := {}
    else
      let (next, scalar) := decoder.feed byte
      decoder := next
      if scalar.isSome then chars := chars + 1
  return { chars := chars, bytes := state.bytes + input.size, decoder := decoder }

private def wcUnicodeCharFile (file : String) : IO WcCounts := do
  let transducer : ByteStreamTransducer WcUnicodeCharState WcCounts :=
    { initial := {}
      step := fun state input => (wcUnicodeCharChunk state input, ByteArray.empty)
      finish := fun state => (ByteArray.empty,
        { chars := state.chars, bytes := state.bytes }) }
  runByteStream file ByteChunkSize.fourMiB transducer

structure WcWidthState where
  column : Nat := 0
  maximum : Nat := 0
  decoder : WcUtf8Decoder := {}

/-- Only the current terminal column and maximum are needed for `-L`. -/
def wcWidthChunk (locale : WcLocale) (state : WcWidthState)
    (input : ByteArray) : WcWidthState := Id.run do
  let mut column := state.column
  let mut maximum := state.maximum
  let mut decoder := state.decoder
  for byte in input do
    let b := byte.toNat
    if b < 128 then
      if decoder.remaining > 0 then decoder := {}
      if b == 10 || b == 13 || b == 12 then
        maximum := max maximum column
        column := 0
      else if b == 9 then column := (column / 8 + 1) * 8
      else if b >= 32 && b < 127 then column := column + 1
    else if locale == .utf8 then
      let (next, scalar) := decoder.feed byte
      decoder := next
      if let some c := scalar then column := column + wcUnicodeWidth c
  return { column := column, maximum := max maximum column, decoder := decoder }

private def wcWidthFile (locale : WcLocale) (file : String) : IO WcCounts := do
  let transducer : ByteStreamTransducer WcWidthState WcCounts :=
    { initial := {}
      step := fun state input => (wcWidthChunk locale state input, ByteArray.empty)
      finish := fun state => (ByteArray.empty, { maxLine := state.maximum }) }
  runByteStream file ByteChunkSize.fourMiB transducer

/-- A pure, bounded-memory Unicode scan; UTF-8 sequences may cross chunks. -/
def wcTextChunk (locale : WcLocale) (state : WcTextState)
    (input : ByteArray) : WcTextState := Id.run do
  let mut lines := state.counts.lines
  let mut words := state.counts.words
  let mut chars := state.counts.chars
  let mut maxLine := state.counts.maxLine
  let mut column := state.column
  let mut inWord := state.inWord
  let mut decoder := state.decoder
  for byte in input do
    let b := byte.toNat
    if b < 128 then
      if locale == .utf8 && decoder.remaining > 0 then
        if !inWord then
          words := words + 1
          inWord := true
        decoder := {}
      if b == 10 then
        lines := lines + 1
      chars := chars + 1
      if wcSpace byte then inWord := false
      else if !inWord then
        words := words + 1
        inWord := true
      if b == 10 || b == 13 || b == 12 then column := 0
      else if b == 9 then column := (column / 8 + 1) * 8
      else if b >= 32 && b < 127 then column := column + 1
      maxLine := max maxLine column
    else if locale == .c then
      if byte == 160 then inWord := false
      else if !inWord then
        words := words + 1
        inWord := true
    else
      if decoder.remaining > 0 && b >= 192 && !inWord then
        words := words + 1
        inWord := true
      let (next, scalar) := decoder.feed byte
      decoder := next
      match scalar with
      | some c =>
          chars := chars + 1
          if wcUnicodeSpace c then inWord := false
          else if !inWord then
            words := words + 1
            inWord := true
          column := column + wcUnicodeWidth c
          maxLine := max maxLine column
      | none =>
          if decoder.remaining == 0 && !inWord then
            words := words + 1
            inWord := true
  return { counts := { lines := lines, words := words,
                       chars := if locale == .c then state.counts.bytes + input.size else chars,
                       bytes := state.counts.bytes + input.size, maxLine := maxLine }
           column := column, inWord := inWord, decoder := decoder }

private def wcTextFile (locale : WcLocale) (file : String) : IO WcCounts := do
  let transducer : ByteStreamTransducer WcTextState WcCounts :=
    { initial := {}
      step := fun state input => (wcTextChunk locale state input, ByteArray.empty)
      finish := fun state => (ByteArray.empty,
        { state.counts with
          words := state.counts.words +
            if locale == .utf8 && state.decoder.remaining > 0 && !state.inWord then 1 else 0 }) }
  runByteStream file ByteChunkSize.fourMiB transducer

/-- `wc [-clmwL] [FILE]...` -/
def runWc : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "wc [OPTION]... [FILE]..." args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut selected : List WcColumn := []
  let mut filesRev : List String := []
  for a in before do
    if a == "-" then
      filesRev := a :: filesRev
    else if a.startsWith "--" then
      match wcLongColumn? a with
      | some column => selected := column :: selected
      | none =>
          reportError prog s!"invalid option -- '{a}'"
          return exitFail
    else if a.startsWith "-" && a.length > 1 then
      for c in a.toList.drop 1 do
        match wcShortColumn? c with
        | some column => selected := column :: selected
        | none =>
            reportError prog s!"invalid option -- '{c}'"
            return exitFail
    else
      filesRev := a :: filesRev
  let files := filesRev.reverse ++ positional
  let columns :=
    if selected.isEmpty then [.lines, .words, .bytes]
    else ([.lines, .words, .chars, .bytes, .maxLine] : List WcColumn).filter selected.contains
  let locale ← wcLocale
  let needsComplex := columns.contains .maxLine ||
    (locale == .utf8 && (columns.contains .chars || columns.contains .words))
  let needsLines := columns.contains .lines
  let needsWords := columns.contains .words
  let scanMode := match needsLines, needsWords with
    | true, true => WcScanMode.linesAndWords
    | true, false => .lines
    | false, true => .words
    | false, false => .bytes
  let allFiles := operandsOrStdin files
  let pick (c : WcCounts) : List Nat :=
    columns.map (·.value c)
  let mut rows : List (List Nat × String) := []
  let mut total : WcCounts := {}
  let mut status := exitOk
  for file in allFiles do
    try
      let counts ←
        if columns == [.maxLine] then wcWidthFile locale file
        else if locale == .utf8 && columns == [.chars] then wcUnicodeCharFile file
        else if locale == .utf8 && needsWords && !columns.contains .chars &&
            !columns.contains .maxLine then wcUnicodeWordFile scanMode file
        else if needsComplex then wcTextFile locale file
        else wcScanFile scanMode file
      let counts := if locale == .c && columns.contains .chars then
        { counts with chars := counts.bytes }
        else counts
      total := { lines := total.lines + counts.lines
                 words := total.words + counts.words
                 chars := total.chars + counts.chars
                 bytes := total.bytes + counts.bytes
                 maxLine := max total.maxLine counts.maxLine }
      rows := (pick counts, file) :: rows
    catch e =>
      reportFileError prog file e
      status := exitFail
  rows := rows.reverse
  if allFiles.length > 1 && !rows.isEmpty then
    rows := rows ++ [(pick total, "total")]
  -- Column width from the largest printed value (GNU does likewise).
  let largest := rows.foldl (fun m (nums, _) => nums.foldl max m) 0
  let width :=
    if columns.length > 1 && allFiles.contains "-" then
      max 7 (toString largest).length
    else
      (toString largest).length
  for (nums, name) in rows do
    let cells := " ".intercalate (nums.map (padLeft width ' ' ∘ toString))
    if name == "-" && files.isEmpty then
      IO.println cells
    else
      IO.println s!"{cells} {name}"
  return status

/-- Multicall registration for `wc`. -/
abbrev WcApplet := AppletTag "wc" runWc

end Lutils
