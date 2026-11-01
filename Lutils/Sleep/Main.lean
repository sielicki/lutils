/-
`sleep` duration parsing and execution. Durations use exact decimal
arithmetic and a ParseIt grammar for their lexical form.
-/
import Lutils.Shared.Common
import ParseIt

namespace Lutils

open ParseIt ParseIt.Char

private abbrev DurationParser :=
  ParseIt.Parser ParseIt.Error.Trivial ParseIt.CharIterator Char

/-- Parse the decimal and suffix as one grammar; keep arithmetic exact. -/
private def sleepDurationMs : DurationParser Nat := do
  let _ ← option? (char '+')
  let whole ← option? ASCII.parseNat
  let fraction ← option? (char '.' *> takeMany ASCII.digit)
  if whole.isNone && (fraction.map (·.isEmpty)).getD true then
    throwUnexpected
  let digits := fraction.getD #[]
  let denom := 10 ^ digits.size
  let numer := whole.getD 0 * denom + digits.foldl (fun n d => n * 10 + d.val) 0
  let suffix ← option? (char 's' <|> char 'm' <|> char 'h' <|> char 'd')
  endOfInput
  let mult := match suffix with
    | some 'm' => 60_000
    | some 'h' => 3_600_000
    | some 'd' => 86_400_000
    | _ => 1000
  return (numer * mult + denom / 2) / denom

/-- Parse one `sleep` duration operand into milliseconds. -/
def parseSleepDuration (prog s : String) : IO (Except UInt32 Nat) := do
  match sleepDurationMs.parseString s with
  | .ok ms => return .ok ms
  | .error _ =>
      reportError prog s!"invalid time interval '{s}'"
      return .error exitFail

private def sleepMs (ms : Nat) : IO Unit := do
  let mut remaining := ms
  while remaining > 0 do
    let chunk := min remaining 60_000
    IO.sleep chunk.toUInt32
    remaining := remaining - chunk

/-- `sleep NUMBER[SUFFIX]...`: pause for the sum of the durations. -/
def runSleep : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "sleep NUMBER[SUFFIX]..." args then
    return code
  let (before, positional) := splitDoubleDash args
  let operands := before ++ positional
  if operands.isEmpty then
    reportError prog "missing operand"
    IO.eprintln s!"Usage: sleep NUMBER[SUFFIX]..."
    return exitFail
  let mut total := 0
  for a in operands do
    if a.startsWith "-" then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    match ← parseSleepDuration prog a with
    | .error code => return code
    | .ok ms => total := total + ms
  sleepMs total
  return exitOk

/-- Multicall registration for `sleep`. -/
abbrev SleepApplet := AppletTag "sleep" runSleep

end Lutils
