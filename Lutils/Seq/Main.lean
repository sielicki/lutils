/-
`seq`: print a sequence of numbers. Arithmetic is exact decimal arithmetic
on scaled integers (unlike GNU's floating point), so `seq 0 0.1 0.3` prints
exactly `0`, `0.1`, `0.2`, `0.3`.
-/
import Lutils.Shared.Common

namespace Lutils

/-- A decimal number `value / 10^scale`. -/
structure Decimal where
  value : Int
  scale : Nat
  negativeZero : Bool := false
  deriving Repr

/-- Keep exact decimal operations within a practical allocation bound. -/
def maxDecimalScale : Nat := 10000

/-- Parse a decimal literal such as `-12`, `0.5`, `.5`, `1e3`, `1.5e-2`. -/
def parseDecimal (s : String) : Option Decimal := do
  let cs := s.toList.dropWhile isAsciiSpace
  let (neg, cs) : Bool × List Char :=
    match cs with
    | '-' :: t => (true, t)
    | '+' :: t => (false, t)
    | _ => (false, cs)
  -- Split off the exponent part.
  let (mantissa, expPart) : List Char × List Char :=
    match cs.idxOf? 'e' with
    | some i => (cs.take i, cs.drop (i + 1))
    | none =>
        match cs.idxOf? 'E' with
        | some i => (cs.take i, cs.drop (i + 1))
        | none => (cs, [])
  let expVal : Int ←
    if expPart.isEmpty && !cs.contains 'e' && !cs.contains 'E' then some 0
    else (String.ofList expPart).toInt?
  let (wholeCs, fracCs) : List Char × List Char :=
    match mantissa.idxOf? '.' with
    | some i => (mantissa.take i, mantissa.drop (i + 1))
    | none => (mantissa, [])
  if wholeCs.isEmpty && fracCs.isEmpty then none
  else if !(wholeCs.all Char.isDigit && fracCs.all Char.isDigit) then none
  else
    let adjustedScale : Int := (fracCs.length : Int) - expVal
    if fracCs.length > maxDecimalScale ||
        adjustedScale > maxDecimalScale || adjustedScale < -(maxDecimalScale : Int) then
      none
    else
      let whole := (String.ofList wholeCs).toNat?.getD 0
      let frac := (String.ofList fracCs).toNat?.getD 0
      let mantissa : Int := whole * 10 ^ fracCs.length + frac
      let value :=
        if adjustedScale < 0 then mantissa * 10 ^ (-adjustedScale).toNat
        else mantissa
      let scale := if adjustedScale < 0 then 0 else adjustedScale.toNat
      some { value := if neg then -value else value, scale,
             negativeZero := neg && value == 0 }

/-- View `d` at the given (larger or equal) scale. -/
def Decimal.atScale (d : Decimal) (scale : Nat) : Int :=
  d.value * 10 ^ (scale - d.scale)

/-- Format a scaled integer with exactly `scale` fractional digits. -/
def formatScaled (value : Int) (scale : Nat) : String :=
  if scale == 0 then
    toString value
  else
    let sign := if value < 0 then "-" else ""
    let digits := padLeft (scale + 1) '0' (toString value.natAbs)
    let cs := digits.toList
    let splitAt := cs.length - scale
    let whole := String.ofList (cs.take splitAt)
    let frac := String.ofList (cs.drop splitAt)
    s!"{sign}{whole}.{frac}"

inductive SeqFormatKind where
  | fixed
  | general

structure SeqFormat where
  leading : String
  trailing : String
  width : Nat := 0
  precision : Option Nat := none
  left : Bool := false
  plus : Bool := false
  space : Bool := false
  zero : Bool := false
  kind : SeqFormatKind := .general

/-- The three required numbers after applying `seq`'s positional defaults. -/
structure SeqRange where
  first : Decimal
  increment : Decimal
  last : Decimal
  incrementText : String

/-- A leading minus followed by a digit or dot starts a numeric operand. -/
def startsNegativeNumber (arg : String) : Bool :=
  match arg.toList with
  | '-' :: second :: _ => second.isDigit || second == '.'
  | _ => false

def seqFormatFlag? (chars : Array Char) (index : Nat) : Option Char :=
  match chars[index]? with
  | some flag =>
      if flag == '-' || flag == '+' || flag == ' ' || flag == '0' then some flag else none
  | none => none

def seqFormatDigit? (chars : Array Char) (index : Nat) : Option Char :=
  match chars[index]? with
  | some digit => if digit.isDigit then some digit else none
  | none => none

/-- Parse the one numeric conversion allowed by GNU `seq -f`. -/
def parseSeqFormat (format : String) : Except String SeqFormat := Id.run do
  let chars := format.toList.toArray
  let mut i := 0
  let mut before := ""
  let mut after := ""
  let mut spec : Option SeqFormat := none
  while i < chars.size do
    let some c := chars[i]? | break
    i := i + 1
    if c != '%' then
      if spec.isSome then after := after.push c else before := before.push c
    else if chars[i]? == some '%' then
      i := i + 1
      if spec.isSome then after := after.push '%' else before := before.push '%'
    else if spec.isSome then
      return .error s!"format '{format}' has too many % directives"
    else if i == chars.size then
      return .error s!"format '{format}' ends in %"
    else
      let mut left := false
      let mut plus := false
      let mut space := false
      let mut zero := false
      while (seqFormatFlag? chars i).isSome do
        let some flag := seqFormatFlag? chars i | break
        if flag == '-' then left := true
        if flag == '+' then plus := true
        if flag == ' ' then space := true
        if flag == '0' then zero := true
        i := i + 1
      let mut widthDigits := ""
      while (seqFormatDigit? chars i).isSome do
        let some digit := seqFormatDigit? chars i | break
        widthDigits := widthDigits.push digit
        i := i + 1
      let mut precision : Option Nat := none
      if chars[i]? == some '.' then
        i := i + 1
        let mut digits := ""
        while (seqFormatDigit? chars i).isSome do
          let some digit := seqFormatDigit? chars i | break
          digits := digits.push digit
          i := i + 1
        precision := some (digits.toNat?.getD 0)
      if i == chars.size then
        return .error s!"format '{format}' ends in %"
      let kind ← match chars[i]? with
        | some 'f' => pure SeqFormatKind.fixed
        | some 'g' => pure SeqFormatKind.general
        | _ => return .error s!"format '{format}' has an unknown % directive"
      i := i + 1
      spec := some { leading := before, trailing := "", width := widthDigits.toNat?.getD 0,
                     precision, left, plus, space, zero, kind }
  match spec with
  | none => return .error s!"format '{format}' has no % directive"
  | some s => return .ok { s with trailing := after }

def renderSeqFormat (spec : SeqFormat) (value : Int) (scale : Nat)
    (negativeZero : Bool) : String :=
  let precision := match spec.kind with
    | .fixed => spec.precision.getD 6
    | .general => scale
  let absValue : Nat := value.natAbs
  let rounded : Nat :=
    if scale > precision then
      let divisor := 10 ^ (scale - precision)
      (absValue + divisor / 2) / divisor
    else absValue * 10 ^ (precision - scale)
  let body := formatScaled rounded precision
  let sign := if value < 0 || negativeZero then "-"
              else if spec.plus then "+" else if spec.space then " " else ""
  let signed := sign ++ body
  let missing := spec.width - signed.length
  let padding := String.ofList (List.replicate missing (if spec.zero && !spec.left then '0' else ' '))
  let padded := if spec.left then signed ++ padding
                else if spec.zero then sign ++ padding ++ body
                else padding ++ signed
  spec.leading ++ padded ++ spec.trailing

/-- `seq [-w] [-s SEPARATOR] [FIRST [INCREMENT]] LAST` -/
def runSeq : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "seq [OPTION]... LAST\n  or:  seq [OPTION]... FIRST LAST\n  or:  seq [OPTION]... FIRST INCREMENT LAST" args then
    return code
  let mut equalWidth := false
  let mut separator := "\n"
  let mut terminator := "\n"
  let mut format : Option String := none
  let mut operandsRev : List String := []
  let mut i := 0
  let arr := args.toArray
  let mut stopOpts := false
  while i < arr.size do
    let some a := arr[i]? | break
    i := i + 1
    if stopOpts then
      operandsRev := a :: operandsRev
    else if a == "--" then
      stopOpts := true
    else if a == "-w" || a == "--equal-width" then
      equalWidth := true
    else if a == "-s" || a == "--separator" then
      match arr[i]? with
      | some value =>
          separator := value
          i := i + 1
      | none =>
          reportError prog "option requires an argument -- 's'"
          return exitFail
    else if a.startsWith "--separator=" then
      separator := String.ofList (a.toList.drop "--separator=".length)
    else if a.startsWith "-s" && a.length > 2 then
      separator := String.ofList (a.toList.drop 2)
    else if a == "-t" || a == "--terminator" then
      match arr[i]? with
      | some value =>
          terminator := value
          i := i + 1
      | none =>
          reportError prog "option requires an argument -- 't'"
          return exitFail
    else if a.startsWith "--terminator=" then
      terminator := String.ofList (a.toList.drop "--terminator=".length)
    else if a.startsWith "-t" && a.length > 2 then
      terminator := String.ofList (a.toList.drop 2)
    else if a == "-f" || a == "--format" then
      match arr[i]? with
      | some value =>
          format := some value
          i := i + 1
      | none =>
          reportError prog "option requires an argument -- 'f'"
          return exitFail
    else if a.startsWith "--format=" then
      format := some (String.ofList (a.toList.drop "--format=".length))
    else if a.startsWith "-f" && a.length > 2 then
      format := some (String.ofList (a.toList.drop 2))
    else if a == "-nan" || a == "-NaN" then
      operandsRev := a :: operandsRev
    else if a.startsWith "-" && a.length > 1 && !startsNegativeNumber a then
      reportError prog s!"invalid option -- '{a}'"
      IO.eprintln s!"Usage: seq [OPTION]... [FIRST [INCREMENT]] LAST"
      return exitFail
    else
      operandsRev := a :: operandsRev
  let formatSpec : Option SeqFormat ←
    match format with
    | none => pure none
    | some value =>
        match parseSeqFormat value with
        | .ok spec => pure (some spec)
        | .error msg =>
            reportError prog msg
            return exitFail
  if equalWidth && formatSpec.isSome then
    reportError prog "format string may not be specified when printing equal width strings"
    return exitFail
  let mut parsed : List (Decimal × String) := []
  for op in operandsRev.reverse do
    match parseDecimal op with
    | some d => parsed := (d, op) :: parsed
    | none =>
        let normalized := op.toLower.toList.dropWhile (· == '-') |> String.ofList
        if normalized == "nan" then
          reportError prog s!"invalid 'not-a-number' argument: '{op}'"
        else
          reportError prog s!"invalid floating point argument: '{op}'"
        IO.eprintln s!"Try '{prog} --help' for more information."
        return exitFail
  let range : SeqRange ←
    match parsed.reverse with
    | [(last, _)] =>
        pure ⟨⟨1, 0, false⟩, ⟨1, 0, false⟩, last, "1"⟩
    | [(first, _), (last, _)] =>
        pure ⟨first, ⟨1, 0, false⟩, last, "1"⟩
    | [(first, _), (increment, incrementText), (last, _)] =>
        pure ⟨first, increment, last, incrementText⟩
    | [] =>
        reportError prog "missing operand"
        IO.eprintln s!"Usage: seq [OPTION]... [FIRST [INCREMENT]] LAST"
        return exitFail
    | _ :: _ :: _ :: (_, extra) :: _ =>
        reportError prog s!"extra operand '{extra}'"
        return exitFail
  if range.increment.value == 0 then
    reportError prog s!"invalid Zero increment value: '{range.incrementText}'"
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  let scale := max (max range.first.scale range.increment.scale) range.last.scale
  let displayScale := max range.first.scale range.increment.scale
  let lo := range.first.atScale scale
  let step := range.increment.atScale scale
  let hi := range.last.atScale scale
  -- Generate values (exact decimal arithmetic), then restore their order.
  let mut values : List Int := []
  let mut cur := lo
  if step > 0 then
    while cur <= hi do
      values := cur :: values
      cur := cur + step
  else
    while cur >= hi do
      values := cur :: values
      cur := cur + step
  let rendered := values.reverse.zipIdx.map fun (value, index) =>
    let negZero := index == 0 && range.first.negativeZero
    match formatSpec with
    | some spec => renderSeqFormat spec value scale negZero
    | none =>
        let value := value / (10 ^ (scale - displayScale) : Int)
        if negZero && value == 0 then "-" ++ formatScaled value displayScale
        else formatScaled value displayScale
  let rendered :=
    if equalWidth then
      let width := rendered.foldl (fun m s => max m s.length) 0
      rendered.map fun s =>
        if s.startsWith "-" then
          "-" ++ padLeft (width - 1) '0' (String.ofList (s.toList.drop 1))
        else
          padLeft width '0' s
    else
      rendered
  try
    if !rendered.isEmpty then
      putStr (separator.intercalate rendered ++ terminator)
    return exitOk
  catch e =>
    return if isBrokenPipe e then exitOk else exitFail

/-- Multicall registration for `seq`. -/
abbrev SeqApplet := AppletTag "seq" runSeq

end Lutils
