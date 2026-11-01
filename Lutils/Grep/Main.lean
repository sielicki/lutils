/- Streaming, byte-preserving line selection. -/
import Lutils.Shared.DelimitedReader
import Lutils.Grep.Regex

namespace Lutils

/-- A search pattern is independent of the storage used for input records. -/
structure GrepPattern where
  bytes : ByteArray
  compiled : Option GrepRegex := none

inductive GrepSyntax where
  | basic | extended | fixed
  deriving BEq

structure GrepOptions where
  mode : GrepSyntax := .basic
  patterns : List GrepPattern := []
  patternFiles : List String := []
  ignoreCase : Bool := false
  invert : Bool := false
  lineNumber : Bool := false
  byteOffset : Bool := false
  count : Bool := false
  filesWithMatches : Bool := false
  filesWithoutMatch : Bool := false
  quiet : Bool := false
  noMessages : Bool := false
  showFilename : Option Bool := none
  wholeLine : Bool := false
  wholeWord : Bool := false
  onlyMatching : Bool := false
  zeroTerminated : Bool := false
  maxCount : Option Nat := none
  operands : List String := []

/-- ASCII case folding is byte preserving outside the ASCII alphabet. -/
def grepFold (ignoreCase : Bool) (byte : UInt8) : UInt8 :=
  if ignoreCase && 65 ≤ byte.toNat && byte.toNat ≤ 90 then byte + 32 else byte

theorem grepFold_identity (byte : UInt8) : grepFold false byte = byte := by
  simp [grepFold]

def grepFoldBytes (ignoreCase : Bool) (bytes : ByteArray) : ByteArray :=
  ByteArray.mk (bytes.data.map (grepFold ignoreCase))

/-- Match a fixed pattern at a known byte position. -/
def grepAt (pattern line : ByteArray) (offset : Nat) (ignoreCase : Bool) : Bool := Id.run do
  if hfit : offset + pattern.size ≤ line.size then
    for h : i in [:pattern.size] do
      have hi : i < pattern.size := h.2.1
      let a := pattern[i]'hi
      let b := line[offset + i]'(by omega)
      if grepFold ignoreCase a != grepFold ignoreCase b then return false
    return true
  else return false

theorem grepAt_too_long (pattern line : ByteArray) (offset : Nat)
    (ignoreCase : Bool) (h : line.size < offset + pattern.size) :
    grepAt pattern line offset ignoreCase = false := by
  simp [grepAt, Nat.not_le.mpr h]

/-- ASCII word bytes for `-w` boundaries. -/
def grepWordByte (byte : UInt8) : Bool :=
  (65 ≤ byte.toNat && byte.toNat ≤ 90) ||
  (97 ≤ byte.toNat && byte.toNat ≤ 122) ||
  (48 ≤ byte.toNat && byte.toNat ≤ 57) || byte == 95

def grepBoundary (line : ByteArray) (start length : Nat) : Bool :=
  let left := if hstart : start = 0 then true
    else if hsize : start ≤ line.size then
      !grepWordByte (line[start - 1]'(by omega))
    else true
  let right := if hend : start + length < line.size then
      !grepWordByte (line[start + length]'hend)
    else true
  left && right

/-- Pure fixed-string search. It returns the first eligible match position. -/
def grepFindFixed (pattern line : ByteArray) (ignoreCase wholeLine wholeWord : Bool) :
    Option Nat := Id.run do
  if wholeLine then
    if pattern.size == line.size && grepAt pattern line 0 ignoreCase then return some 0
    return none
  if hfit : pattern.size ≤ line.size then
    if hpat : 0 < pattern.size then
      let first := grepFold ignoreCase (pattern[0]'hpat)
      let limit := line.size - pattern.size + 1
      for h : offset in [:limit] do
        have hcurrent : offset < limit := h.2.1
        have hline : offset < line.size := by dsimp [limit] at hcurrent; omega
        if grepFold ignoreCase (line[offset]'hline) == first &&
            grepAt pattern line offset ignoreCase &&
            (!wholeWord || grepBoundary line offset pattern.size) then
          return some offset
    else
      for offset in [:line.size + 1] do
        if grepAt pattern line offset ignoreCase &&
            (!wholeWord || grepBoundary line offset 0) then
          return some offset
  else return none
  return none

theorem grepFindFixed_wholeLine_length (pattern line : ByteArray) (ignoreCase word : Bool)
    (h : pattern.size ≠ line.size) :
    grepFindFixed pattern line ignoreCase true word = none := by
  simp [grepFindFixed, h]

def GrepOptions.matches (opts : GrepOptions) (line : ByteArray) : Bool :=
  opts.patterns.any fun pattern =>
    if opts.mode == .fixed then
      (grepFindFixed pattern.bytes line opts.ignoreCase opts.wholeLine opts.wholeWord).isSome
    else
      match pattern.compiled with
      | none => false
      | some regex =>
          let input := grepFoldBytes opts.ignoreCase line
          let regex := if opts.wholeLine then
            { regex with startAnchor := true, endAnchor := true } else regex
          if opts.wholeWord then
            regex.matchesBounds input fun start stop => grepBoundary input start (stop - start)
          else regex.matches input

/-- Inversion changes selection, not the underlying match result. -/
def GrepOptions.selects (opts : GrepOptions) (line : ByteArray) : Bool :=
  opts.matches line != opts.invert

/-- The next nonempty match for `-o`; output offsets refer to the original line. -/
def GrepOptions.firstPositive (opts : GrepOptions) (line : ByteArray)
    (fromOffset : Nat) : Option (Nat × Nat) := Id.run do
  let mut best : Option (Nat × Nat) := none
  for pattern in opts.patterns do
    let candidate := if opts.mode == .fixed then Id.run do
      let mut found := none
      for start in [fromOffset:line.size + 1] do
        if pattern.bytes.size > 0 && grepAt pattern.bytes line start opts.ignoreCase &&
            (!opts.wholeLine || (start == 0 && pattern.bytes.size == line.size)) &&
            (!opts.wholeWord || grepBoundary line start pattern.bytes.size) then
          found := some (start, start + pattern.bytes.size)
          break
      return found
    else match pattern.compiled with
      | none => none
      | some regex =>
          let regex := if opts.wholeLine then
            { regex with startAnchor := true, endAnchor := true } else regex
          regex.findPositive (grepFoldBytes opts.ignoreCase line) fromOffset
    if let some (start, stop) := candidate then
      if !opts.wholeWord || grepBoundary line start (stop - start) then
        match best with
        | none => best := some (start, stop)
        | some (oldStart, oldStop) =>
          if start < oldStart || (start == oldStart && stop > oldStop) then
            best := some (start, stop)
  return best

theorem GrepOptions.selects_inverted (opts : GrepOptions) (line : ByteArray) :
    ({ opts with invert := !opts.invert }).selects line = !opts.selects line := by
  cases opts <;> simp [GrepOptions.selects, GrepOptions.matches]

private partial def grepParse (args : List String) : Except String GrepOptions :=
  go {} false args
where
  go (opts : GrepOptions) (literal : Bool) : List String → Except String GrepOptions
    | [] => .ok opts
    | arg :: rest =>
      if literal then go { opts with operands := opts.operands ++ [arg] } true rest
      else if arg == "--" then go opts true rest
      else if arg == "-" || !arg.startsWith "-" then
        go { opts with operands := opts.operands ++ [arg] } false rest
      else if arg == "--fixed-strings" then go { opts with mode := .fixed } false rest
      else if arg == "--basic-regexp" then go { opts with mode := .basic } false rest
      else if arg == "--extended-regexp" then go { opts with mode := .extended } false rest
      else if arg == "--ignore-case" then go { opts with ignoreCase := true } false rest
      else if arg == "--invert-match" then go { opts with invert := true } false rest
      else if arg == "--line-number" then go { opts with lineNumber := true } false rest
      else if arg == "--byte-offset" then go { opts with byteOffset := true } false rest
      else if arg == "--count" then go { opts with count := true } false rest
      else if arg == "--files-with-matches" then go { opts with filesWithMatches := true } false rest
      else if arg == "--files-without-match" then go { opts with filesWithoutMatch := true } false rest
      else if arg == "--quiet" || arg == "--silent" then go { opts with quiet := true } false rest
      else if arg == "--no-messages" then go { opts with noMessages := true } false rest
      else if arg == "--with-filename" then go { opts with showFilename := some true } false rest
      else if arg == "--no-filename" then go { opts with showFilename := some false } false rest
      else if arg == "--line-regexp" then go { opts with wholeLine := true } false rest
      else if arg == "--word-regexp" then go { opts with wholeWord := true } false rest
      else if arg == "--only-matching" then go { opts with onlyMatching := true } false rest
      else if arg == "--null-data" then go { opts with zeroTerminated := true } false rest
      else if arg == "--regexp" then
        match rest with
        | [] => .error "option '--regexp' requires an argument"
        | value :: tail => go { opts with patterns := opts.patterns ++ [{ bytes := value.toUTF8 }] } false tail
      else if arg.startsWith "--regexp=" then
        go { opts with patterns := opts.patterns ++ [{ bytes := (arg.drop 9).toString.toUTF8 }] } false rest
      else if arg == "--file" then
        match rest with
        | [] => .error "option '--file' requires an argument"
        | value :: tail => go { opts with patternFiles := opts.patternFiles ++ [value] } false tail
      else if arg.startsWith "--file=" then
        go { opts with patternFiles := opts.patternFiles ++ [(arg.drop 7).toString] } false rest
      else if arg == "--max-count" then
        match rest with
        | [] => .error "option '--max-count' requires an argument"
        | value :: tail =>
          match value.toNat? with
          | some n => go { opts with maxCount := some n } false tail
          | none => .error s!"invalid max count '{value}'"
      else if arg.startsWith "--max-count=" then
        let value := (arg.drop 12).toString
        match value.toNat? with
        | some n => go { opts with maxCount := some n } false rest
        | none => .error s!"invalid max count '{value}'"
      else if arg.startsWith "--" then .error s!"unrecognized option '{arg}'"
      else applyShort opts (arg.drop 1).toString.toList rest
  applyShort (opts : GrepOptions) : List Char → List String → Except String GrepOptions
    | [], rest => go opts false rest
    | c :: chars, rest =>
      let next : Option GrepOptions := match c with
        | 'F' => some { opts with mode := .fixed }
        | 'G' => some { opts with mode := .basic }
        | 'E' => some { opts with mode := .extended }
        | 'i' => some { opts with ignoreCase := true }
        | 'v' => some { opts with invert := true }
        | 'n' => some { opts with lineNumber := true }
        | 'b' => some { opts with byteOffset := true }
        | 'c' => some { opts with count := true }
        | 'l' => some { opts with filesWithMatches := true }
        | 'L' => some { opts with filesWithoutMatch := true }
        | 'q' => some { opts with quiet := true }
        | 's' => some { opts with noMessages := true }
        | 'H' => some { opts with showFilename := some true }
        | 'h' => some { opts with showFilename := some false }
        | 'x' => some { opts with wholeLine := true }
        | 'w' => some { opts with wholeWord := true }
        | 'o' => some { opts with onlyMatching := true }
        | 'z' => some { opts with zeroTerminated := true }
        | _ => none
      if let some updated := next then applyShort updated chars rest
      else if c == 'e' || c == 'f' || c == 'm' then
        let valueAndRest := if chars.isEmpty then
          match rest with
          | [] => none
          | value :: tail => some (value, tail)
          else some (String.ofList chars, rest)
        match valueAndRest with
        | none => .error s!"option requires an argument -- '{c}'"
        | some (value, tail) =>
          if c == 'e' then go { opts with patterns := opts.patterns ++ [{ bytes := value.toUTF8 }] } false tail
          else if c == 'f' then go { opts with patternFiles := opts.patternFiles ++ [value] } false tail
          else match value.toNat? with
            | some n => go { opts with maxCount := some n } false tail
            | none => .error s!"invalid max count '{value}'"
      else .error s!"invalid option -- '{c}'"

private def grepSplitPatterns (data : ByteArray) : List GrepPattern :=
  if data.isEmpty then [] else Id.run do
    let parts := data.toList.splitOn 10
    let parts := if data[data.size - 1]! == 10 then parts.dropLast else parts
    return parts.map fun bytes => { bytes := ByteArray.mk bytes.toArray : GrepPattern }

/-- Split ERE alternatives outside bracket expressions and escapes. -/
private def grepAlternatives (extended : Bool) (pattern : ByteArray) : List ByteArray :=
  (go [] [] false false pattern.toList).reverse
where
  go (current : List UInt8) (branches : List ByteArray) (inClass escaped : Bool) :
      List UInt8 → List ByteArray
    | [] => ByteArray.mk current.reverse.toArray :: branches
    | 92 :: 124 :: rest =>
      if !extended && !inClass && !escaped then
        go [] (ByteArray.mk current.reverse.toArray :: branches) false false rest
      else go (92 :: current) branches inClass (!escaped) (124 :: rest)
    | byte :: rest =>
      if escaped then go (byte :: current) branches inClass false rest
      else if byte == 92 then go (byte :: current) branches inClass true rest
      else if byte == 91 then go (byte :: current) branches true false rest
      else if byte == 93 then go (byte :: current) branches false false rest
      else if byte == 124 && extended && !inClass then
        go [] (ByteArray.mk current.reverse.toArray :: branches) false false rest
      else go (byte :: current) branches inClass false rest

private def grepOpen (path : String) (terminator : UInt8) : IO DelimitedReader := do
  let handle ← if path == "-" then IO.getStdin
    else IO.FS.Stream.ofHandle <$> IO.FS.Handle.mk path .read
  return { handle := handle, terminator := terminator }

private def grepLabel (path : String) : String :=
  if path == "-" then "(standard input)" else path

private def grepPrefix (opts : GrepOptions) (path : String) (showName : Bool)
    (lineNumber byteOffset : Nat) : ByteArray := Id.run do
  let mut out := ByteArray.empty
  if showName then out := (out.fastAppend (grepLabel path).toUTF8).push 58
  if opts.lineNumber then out := (out.fastAppend (toString lineNumber).toUTF8).push 58
  if opts.byteOffset then out := (out.fastAppend (toString byteOffset).toUTF8).push 58
  return out

/-- Find a nonempty literal within one byte-buffer segment. The first-byte
guard avoids entering the full matcher at positions that cannot match. -/
private def grepFindInSegment (pattern chunk : ByteArray) (start stop : Nat) : Bool := Id.run do
  if hpat : 0 < pattern.size then
    if hstart : start ≤ stop then
      if hstop : stop ≤ chunk.size then
        if hlength : pattern.size ≤ stop - start then
          let first := pattern[0]'hpat
          let limit := stop - pattern.size + 1
          for h : offset in [start:limit] do
            have hoffset : offset < limit := h.2.1
            have hbyte : offset < chunk.size := by dsimp [limit] at hoffset; omega
            if chunk[offset]'hbyte == first && grepAt pattern chunk offset false then
              return true
  return false

/-- Only an unfinished record crosses chunk boundaries. Complete unmatched
records in a chunk are never copied into separate byte arrays. -/
structure GrepLiteralScan where
  pending : ByteArray := ByteArray.empty
  found : Bool := false

def GrepLiteralScan.feed (state : GrepLiteralScan) (pattern chunk : ByteArray)
    (terminator : UInt8) : GrepLiteralScan × ByteArray := Id.run do
  let mut pending := state.pending
  let mut found := state.found
  let mut output := ByteArray.empty
  let mut start := 0
  for h : i in [:chunk.size] do
    if chunk[i] == terminator then
      if pending.isEmpty then
        if grepFindInSegment pattern chunk start i then
          output := (output.fastAppend (chunk.extract start i)).push terminator
          found := true
      else
        let record := pending.fastAppend (chunk.extract start i)
        if (grepFindFixed pattern record false false false).isSome then
          output := (output.fastAppend record).push terminator
          found := true
      pending := ByteArray.empty
      start := i + 1
  if start < chunk.size then
    let fragment := chunk.extract start chunk.size
    pending := if pending.isEmpty then fragment else pending.fastAppend fragment
  return ({ pending := pending, found := found }, output)

/-- An empty read leaves the scan state and its output unchanged. -/
theorem GrepLiteralScan.feed_empty (state : GrepLiteralScan) (pattern : ByteArray)
    (terminator : UInt8) :
    state.feed pattern ByteArray.empty terminator = (state, ByteArray.empty) := by
  cases state
  simp [GrepLiteralScan.feed]

def GrepLiteralScan.finish (state : GrepLiteralScan) (pattern : ByteArray)
    (terminator : UInt8) : Bool × ByteArray :=
  if state.pending.isEmpty then (state.found, ByteArray.empty)
  else if (grepFindFixed pattern state.pending false false false).isSome then
    (true, state.pending.push terminator)
  else (state.found, ByteArray.empty)

/-- Single-pattern literal search retains bounded memory even for long lines. -/
private def grepProcessLiteral (path : String) (pattern : ByteArray)
    (terminator : UInt8) : IO Bool := do
  let readChunk ← operandChunkReader path ByteChunkSize.fourMiB
  let output ← IO.getStdout
  let mut state : GrepLiteralScan := {}
  repeat
    let chunk ← readChunk
    if chunk.isEmpty then break
    let (next, bytes) := state.feed pattern chunk terminator
    state := next
    if !bytes.isEmpty then output.write bytes
  let (found, finalBytes) := state.finish pattern terminator
  if !finalBytes.isEmpty then output.write finalBytes
  output.flush
  return found

/-- The fast chunk path applies only when line output needs no extra metadata. -/
private def grepCanScanLiteral (opts : GrepOptions) (showName : Bool) : Bool :=
  opts.mode == .fixed && !opts.ignoreCase && !opts.invert && !showName &&
  !opts.lineNumber && !opts.byteOffset && !opts.count && !opts.filesWithMatches &&
  !opts.filesWithoutMatch && !opts.quiet && !opts.wholeLine && !opts.wholeWord &&
  !opts.onlyMatching && opts.maxCount.isNone

private def grepProcess (opts : GrepOptions) (path : String) (showName : Bool) :
    IO Bool := do
  if grepCanScanLiteral opts showName then
    if let [pattern] := opts.patterns then
      if !pattern.bytes.isEmpty then
        return ← grepProcessLiteral path pattern.bytes (if opts.zeroTerminated then 0 else 10)
  let mut reader ← grepOpen path (if opts.zeroTerminated then 0 else 10)
  let output ← IO.getStdout
  let mut buffer := ByteArray.empty
  let mut lineNumber := 0
  let mut byteOffset := 0
  let mut selected := 0
  repeat
    if opts.maxCount == some selected then break
    let (next, record) ← reader.next
    reader := next
    let some record := record | break
    lineNumber := lineNumber + 1
    if opts.selects record.bytes then
      selected := selected + 1
      if opts.quiet || opts.filesWithMatches || opts.filesWithoutMatch then break
      if !opts.count then
        if opts.onlyMatching then
          if !opts.invert then
            let mut cursor := 0
            for _ in [:record.bytes.size + 1] do
              let some (start, stop) := opts.firstPositive record.bytes cursor | break
              buffer := buffer.fastAppend (grepPrefix opts path showName lineNumber
                (byteOffset + start))
              buffer := (buffer.fastAppend (record.bytes.extract start stop)).push reader.terminator
              cursor := stop
        else
          buffer := buffer.fastAppend (grepPrefix opts path showName lineNumber byteOffset)
          buffer := (buffer.fastAppend record.bytes).push reader.terminator
        if buffer.size >= 64 * 1024 then
          output.write buffer
          buffer := ByteArray.empty
    byteOffset := byteOffset + record.bytes.size + 1
  if opts.filesWithMatches && selected > 0 then
    buffer := buffer.fastAppend ((grepLabel path ++ "\n").toUTF8)
  if opts.filesWithoutMatch && selected == 0 then
    buffer := buffer.fastAppend ((grepLabel path ++ "\n").toUTF8)
  if opts.count && !opts.quiet && !opts.filesWithMatches && !opts.filesWithoutMatch then
    buffer := buffer.fastAppend (grepPrefix opts path showName 0 0)
    buffer := buffer.fastAppend ((toString selected ++ "\n").toUTF8)
  if !buffer.isEmpty then output.write buffer
  output.flush
  return selected > 0

/-- Search records while keeping only one input record and a bounded output buffer. -/
def runGrep : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "grep [OPTION]... PATTERNS [FILE]..." args then
    return code
  let opts ← match grepParse args with
    | .ok opts => pure opts
    | .error message =>
        reportError prog message
        return exitUsage
  let mut opts := opts
  if opts.patterns.isEmpty && opts.patternFiles.isEmpty then
    match opts.operands with
    | [] =>
        reportError prog "missing search pattern"
        return exitUsage
    | pattern :: files =>
        opts := { opts with patterns := [{ bytes := pattern.toUTF8 }], operands := files }
  for path in opts.patternFiles do
    let data ← try
      if path == "-" then readStdinBytes else IO.FS.readBinFile path
    catch error =>
      reportFileError prog path error
      return exitUsage
    opts := { opts with patterns := opts.patterns ++ grepSplitPatterns data }
  opts := { opts with patterns := opts.patterns.flatMap fun pattern =>
    if pattern.bytes.isEmpty then [pattern] else grepSplitPatterns pattern.bytes }
  if opts.mode != .fixed then
    let mut compiled : List GrepPattern := []
    for pattern in opts.patterns do
      let alternatives := grepAlternatives (opts.mode == .extended) pattern.bytes
      for alternative in alternatives do
        let regex ← match grepCompileRegex (opts.mode == .extended)
            (grepFoldBytes opts.ignoreCase alternative) with
          | .ok regex => pure regex
          | .error message =>
              reportError prog message
              return exitUsage
        compiled := { bytes := alternative, compiled := some regex } :: compiled
    opts := { opts with patterns := compiled.reverse }
  let paths := if opts.operands.isEmpty then ["-"] else opts.operands
  let showName := opts.showFilename.getD (paths.length > 1)
  let mut found := false
  let mut hadError := false
  for path in paths do
    try
      let matched ← grepProcess opts path showName
      found := found || matched
      if matched && opts.quiet then return exitOk
    catch error =>
      hadError := true
      if !opts.noMessages then reportFileError prog path error
  if hadError then return exitUsage
  return if found then exitOk else exitFail

end Lutils
