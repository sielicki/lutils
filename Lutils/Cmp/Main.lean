/- Bytewise comparison of bounded input streams. -/
import Lutils.Shared.HeadTail

namespace Lutils

/-- A positive, one-based location in the compared suffixes. -/
structure CmpPosition where
  byte : Nat := 1
  line : Nat := 1
  lastNewline : Bool := false

def CmpPosition.advance (position : CmpPosition) (leftByte : UInt8) : CmpPosition :=
  { byte := position.byte + 1,
    line := position.line + if leftByte == 10 then 1 else 0,
    lastNewline := leftByte == 10 }

theorem CmpPosition.advance_byte (position : CmpPosition) (byte : UInt8) :
    (position.advance byte).byte = position.byte + 1 := rfl

theorem CmpPosition.advance_line_mono (position : CmpPosition) (byte : UInt8) :
    position.line ≤ (position.advance byte).line := by
  simp [CmpPosition.advance]

inductive CmpOutputMode where
  | first | verbose | quiet
  deriving BEq

structure CmpOptions where
  mode : CmpOutputMode := .first
  quietRequested : Bool := false
  verboseRequested : Bool := false
  printBytes : Bool := false
  limit : Option Nat := none
  skipLeft : Nat := 0
  skipRight : Nat := 0
  operands : List String := []

private def cmpDigit (base : Nat) (char : Char) : Option Nat := do
  let code := char.toNat
  let digit := if 48 ≤ code && code ≤ 57 then code - 48
    else if 65 ≤ code && code ≤ 70 then code - 65 + 10
    else if 97 ≤ code && code ≤ 102 then code - 97 + 10
    else 16
  if digit < base then some digit else none

private def cmpCount (s : String) : Except String Nat := do
  let hex := s.startsWith "0x" || s.startsWith "0X"
  let base := if hex then 16 else if s.startsWith "0" then 8 else 10
  let chars := if hex then (s.drop 2).toString.toList else s.toList
  let (digits, suffix) := chars.span (fun c => (cmpDigit base c).isSome)
  if digits.isEmpty then .error s!"invalid number: '{s}'"
  else
    let n := digits.foldl (fun n c => n * base + (cmpDigit base c).getD 0) 0
    match sizeSuffixMultiplier (String.ofList suffix) with
    | some mult => .ok (n * mult)
    | none => .error s!"invalid number: '{s}'"

private def cmpSkip (s : String) : Except String (Nat × Nat) := do
  match s.splitOn ":" with
  | [left] =>
      let count ← cmpCount left
      return (count, count)
  | [left, right] => return (← cmpCount left, ← cmpCount right)
  | _ => .error s!"invalid --ignore-initial value: '{s}'"

private def cmpParse (args : List String) : Except String CmpOptions :=
  go {} false args
where
  go (opts : CmpOptions) (literal : Bool) : List String → Except String CmpOptions
    | [] => .ok opts
    | arg :: rest =>
      if literal then go { opts with operands := opts.operands ++ [arg] } true rest
      else if arg == "--" then go opts true rest
      else if arg == "-" || !arg.startsWith "-" then
        go { opts with operands := opts.operands ++ [arg] } false rest
      else if arg == "--quiet" || arg == "--silent" then
        go { opts with mode := .quiet, quietRequested := true } false rest
      else if arg == "--verbose" then
        go { opts with mode := .verbose, verboseRequested := true } false rest
      else if arg == "--print-bytes" then go { opts with printBytes := true } false rest
      else if arg == "--bytes" || arg == "--ignore-initial" || arg == "-n" || arg == "-i" then
        match rest with
        | [] => .error s!"option '{arg}' requires an argument"
        | value :: tail =>
            if arg == "--bytes" || arg == "-n" then
              (cmpCount value).bind fun n => go { opts with limit := some n } false tail
            else
              (cmpSkip value).bind fun (a, b) =>
                go { opts with skipLeft := a, skipRight := b } false tail
      else if arg.startsWith "--bytes=" then
        (cmpCount (arg.drop "--bytes=".length).toString).bind fun n =>
          go { opts with limit := some n } false rest
      else if arg.startsWith "--ignore-initial=" then
        (cmpSkip (arg.drop "--ignore-initial=".length).toString).bind fun (a, b) =>
          go { opts with skipLeft := a, skipRight := b } false rest
      else if arg.startsWith "--" then .error s!"unrecognized option '{arg}'"
      else
        match short opts (arg.drop 1).toString.toList with
        | .ok next => go next false rest
        | .error message => .error message
  short (opts : CmpOptions) : List Char → Except String CmpOptions
    | [] => .ok opts
    | 's' :: rest => short { opts with mode := .quiet, quietRequested := true } rest
    | 'l' :: rest => short { opts with mode := .verbose, verboseRequested := true } rest
    | 'b' :: rest => short { opts with printBytes := true } rest
    | 'n' :: rest => (cmpCount (String.ofList rest)).map fun n => { opts with limit := some n }
    | 'i' :: rest => (cmpSkip (String.ofList rest)).map fun (a, b) =>
        { opts with skipLeft := a, skipRight := b }
    | c :: _ => .error s!"invalid option -- '{c}'"

/-- Buffer cursor invariant: cursor never exceeds the available bytes. -/
structure CmpSource where
  handle : IO.FS.Stream
  buffer : ByteArray := ByteArray.empty
  cursor : Nat := 0
  ended : Bool := false
  path : String

private def CmpSource.fill (source : CmpSource) : IO CmpSource := do
  if source.cursor < source.buffer.size || source.ended then return source
  let bytes ← source.handle.read (64 * 1024)
  return { source with buffer := bytes, cursor := 0, ended := bytes.isEmpty }

private def CmpSource.skip (source : CmpSource) (count : Nat) : IO CmpSource := do
  let mut current := source
  let mut remaining := count
  while remaining > 0 do
    current ← current.fill
    if current.ended then break
    let available := current.buffer.size - current.cursor
    let step := min available remaining
    current := { current with cursor := current.cursor + step }
    remaining := remaining - step
  return current

private def cmpOpen (path : String) : IO CmpSource := do
  let handle ← if path == "-" then IO.getStdin
    else IO.FS.Stream.ofHandle <$> IO.FS.Handle.mk path .read
  return { path := path, handle := handle }

private def cmpReportFileError (prog path : String) (error : IO.Error) : IO Unit :=
  match error with
  | .inappropriateType _ 21 _ => reportError prog s!"{path}: Is a directory"
  | _ => reportFileError prog path error

/-- ASCII rendering of a byte in GNU's `-b` notation. -/
def cmpByteDisplay (byte : UInt8) : String :=
  let n := byte.toNat
  let low := n % 128
  let marker := if n ≥ 128 then "M-" else ""
  if low < 32 then marker ++ "^" ++ String.singleton (Char.ofNat (low + 64))
  else if low == 127 then marker ++ "^?"
  else marker ++ String.singleton (Char.ofNat low)

private def cmpOctal (byte : UInt8) : String := Id.run do
  let n := byte.toNat
  let digits := if n ≥ 64 then toString (n / 64) else ""
  let digits := digits ++ (if n ≥ 8 then toString ((n / 8) % 8) else "")
  let digits := digits ++ toString (n % 8)
  return String.ofList (List.replicate (3 - digits.length) ' ') ++ digits

private def cmpDiffLine (opts : CmpOptions) (numberWidth : Nat) (position : CmpPosition)
    (left right : UInt8) : String :=
  if opts.mode == .verbose then
    let number := toString position.byte
    let number := String.ofList (List.replicate (numberWidth - number.length) ' ') ++ number
    if opts.printBytes then
      let leftPart := s!"{number} {cmpOctal left} {cmpByteDisplay left}"
      let spaces := String.ofList (List.replicate (number.length + 10 - leftPart.length) ' ')
      leftPart ++ spaces ++ s!"{cmpOctal right} {cmpByteDisplay right}\n"
    else s!"{number} {cmpOctal left} {cmpOctal right}\n"
  else ""

/-- Compare one aligned segment. The output is pure and stops at the first
mismatch unless verbose mode requires all differences. -/
def cmpScan (opts : CmpOptions) (left right : ByteArray)
    (startLeft startRight count numberWidth : Nat) (position : CmpPosition) :
    CmpPosition × Bool × Option (UInt8 × UInt8) × String := Id.run do
  if count > 0 && startLeft + count ≤ left.size && startRight + count ≤ right.size then
    let leftPart := left.extract startLeft (startLeft + count)
    let rightPart := right.extract startRight (startRight + count)
    if leftPart == rightPart then
      let newlines := if opts.mode == .first then
        leftPart.data.foldl (fun n byte => n + if byte == 10 then 1 else 0) 0
        else 0
      let lastNewline := opts.mode == .first && left[startLeft + count - 1]? == some 10
      return ({ byte := position.byte + count, line := position.line + newlines,
                lastNewline := lastNewline }, false, none, "")
  let mut pos := position
  let mut differs := false
  let mut first : Option (UInt8 × UInt8) := none
  let mut lines := ""
  for i in [:count] do
    if hleft : startLeft + i < left.size then
      if hright : startRight + i < right.size then
        let a := left[startLeft + i]'hleft
        let b := right[startRight + i]'hright
        if a != b then
          differs := true
          if first.isNone then first := some (a, b)
          lines := lines ++ cmpDiffLine opts numberWidth pos a b
          if opts.mode != .verbose then return (pos, true, first, lines)
        pos := pos.advance a
  return (pos, differs, first, lines)

/-- Empty comparison segments cannot differ. -/
theorem cmpScan_empty (opts : CmpOptions) (a b : ByteArray)
    (ia ib width : Nat) (pos : CmpPosition) :
    cmpScan opts a b ia ib 0 width pos = (pos, false, none, "") := by
  simp [cmpScan]

private def cmpQuote (path : String) (utf8 : Bool) : String :=
  if utf8 then "‘" ++ path ++ "’" else "'" ++ path ++ "'"

private def cmpKnownSize (path : String) (skip : Nat) : IO (Option Nat) := do
  if path == "-" then return none
  let result ← (System.FilePath.mk path).metadata.toBaseIO
  match result with
  | .ok metadata =>
      if metadata.type == .file then return some (metadata.byteSize.toNat - skip)
      else return none
  | .error _ => return none

private def cmpEof (prog path : String) (position : CmpPosition)
    (mode : CmpOutputMode) (utf8 : Bool) : IO Unit := do
  if mode == .quiet then return
  let details := if position.byte == 1 then "which is empty"
    else if mode == .verbose then s!"after byte {position.byte - 1}"
    else if position.lastNewline then
      s!"after byte {position.byte - 1}, line {position.line - 1}"
    else s!"after byte {position.byte - 1}, in line {position.line}"
  reportError prog s!"EOF on {cmpQuote path utf8} {details}"

/-- `cmp [OPTION]... FILE1 [FILE2 [SKIP1 [SKIP2]]]`. -/
def runCmp : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "cmp [OPTION]... FILE1 [FILE2 [SKIP1 [SKIP2]]]" args then
    return code
  let opts ← match cmpParse args with
    | .ok value => pure value
    | .error message =>
        reportError prog message
        return 2
  if opts.quietRequested && opts.verboseRequested then
    reportError prog "options -l and -s are incompatible"
    reportError prog "Try 'cmp --help' for more information."
    return 2
  let (leftPath, rightPath, extra) ← match opts.operands with
    | [] =>
        reportError prog "missing operand"
        return 2
    | [a] => pure (a, "-", [])
    | a :: b :: rest => pure (a, b, rest)
  let opts ← match extra with
    | [] => pure opts
    | [a] =>
        match cmpCount a with
        | .ok n => pure { opts with skipLeft := n }
        | .error message => reportError prog message; return 2
    | [a, b] =>
        match cmpCount a, cmpCount b with
        | .ok x, .ok y => pure { opts with skipLeft := x, skipRight := y }
        | _, _ => reportError prog "invalid skip value"; return 2
    | _ => reportError prog "extra operand"; return 2
  -- Both operands name the same non-seekable stdin stream. GNU treats it as
  -- self-comparison, including when skip counts differ.
  if leftPath == "-" && rightPath == "-" then return 0
  let mut left ← try cmpOpen leftPath catch error =>
    if opts.mode != .quiet then cmpReportFileError prog leftPath error
    return 2
  let mut right ← try cmpOpen rightPath catch error =>
    if opts.mode != .quiet then cmpReportFileError prog rightPath error
    return 2
  let locale := (← IO.getEnv "LC_ALL").getD "C"
  let utf8 := locale != "C" && locale != "POSIX"
  let leftSize ← cmpKnownSize leftPath opts.skipLeft
  let rightSize ← cmpKnownSize rightPath opts.skipRight
  let knownSize := match leftSize, rightSize with
    | some a, some b => some (min a b)
    | some a, none => some a
    | none, some b => some b
    | none, none => none
  let widthBound := match knownSize, opts.limit with
    | some size, some limit => min size limit
    | some size, none => size
    | none, some limit => limit
    | none, none => 1
  let numberWidth := max 1 (toString widthBound).length
  try
    left ← try left.skip opts.skipLeft catch error =>
      cmpReportFileError prog leftPath error
      return 2
    right ← try right.skip opts.skipRight catch error =>
      cmpReportFileError prog rightPath error
      return 2
    let output ← IO.getStdout
    let mut position : CmpPosition := {}
    let mut differs := false
    repeat
      if let some limit := opts.limit then
        if position.byte > limit then break
      left ← try left.fill catch error =>
        cmpReportFileError prog leftPath error
        return 2
      right ← try right.fill catch error =>
        cmpReportFileError prog rightPath error
        return 2
      if left.ended || right.ended then
        if left.ended != right.ended then
          differs := true
          let path := if left.ended then leftPath else rightPath
          cmpEof prog path position opts.mode utf8
        break
      let available := min (left.buffer.size - left.cursor) (right.buffer.size - right.cursor)
      let count := min available ((opts.limit.getD (position.byte + available)) - (position.byte - 1))
      let (next, changed, first, lines) :=
        cmpScan opts left.buffer right.buffer left.cursor right.cursor count numberWidth position
      if !lines.isEmpty then output.putStr lines
      if changed then
        differs := true
        if opts.mode != .verbose then
          if opts.mode == .first then
            let (a, b) := first.getD (0, 0)
            let suffix := if opts.printBytes then
              s!" is {cmpOctal a} {cmpByteDisplay a} {cmpOctal b} {cmpByteDisplay b}" else ""
            let unit := if opts.printBytes || utf8 then "byte" else "char"
            output.putStr s!"{leftPath} {rightPath} differ: {unit} {next.byte}, line {next.line}{suffix}\n"
          break
      let consumed := next.byte - position.byte
      left := { left with cursor := left.cursor + consumed }
      right := { right with cursor := right.cursor + consumed }
      position := next
    output.flush
    return if differs then 1 else 0
  catch error =>
    reportError prog (describeError error)
    return 2

/-- Multicall registration for `cmp`. -/
abbrev CmpApplet := AppletTag "cmp" runCmp

end Lutils
