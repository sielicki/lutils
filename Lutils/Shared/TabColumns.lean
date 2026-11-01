/- Shared UTF-8 display-column tracking for tab-aware applets. -/
import Lutils.Shared.UnicodeWidth

namespace Lutils

/-- Minimal UTF-8 decoder state carried across input chunks. -/
structure TabUtf8 where
  remaining : Nat := 0
  value : Nat := 0
  minimum : Nat := 0
  seen : Nat := 0

/-- The transducer state is independent of its input buffer size. -/
structure TabColumnState where
  column : Nat := 0
  utf8 : TabUtf8 := {}

def TabColumnState.advance (state : TabColumnState) (byte : UInt8)
    (unicode : Bool) : TabColumnState := Id.run do
  if !unicode || byte.toNat < 128 then
    return { state with column := state.column + state.utf8.seen + 1, utf8 := {} }
  let b := byte.toNat
  if state.utf8.remaining > 0 && 128 ≤ b && b < 192 then
    let scalar := state.utf8.value * 64 + b % 64
    if state.utf8.remaining > 1 then
      let decoder : TabUtf8 :=
        { remaining := state.utf8.remaining - 1, value := scalar,
          minimum := state.utf8.minimum, seen := state.utf8.seen + 1 }
      return { state with utf8 := decoder }
    if scalar ≥ state.utf8.minimum && scalar ≤ 0x10ffff &&
        !(0xd800 ≤ scalar && scalar ≤ 0xdfff) then
      let width := unicodeScalarCells scalar
      return { state with column := state.column + width - 1, utf8 := {} }
    return { state with column := state.column + state.utf8.seen + 1, utf8 := {} }
  if 194 ≤ b && b ≤ 223 then
    let decoder : TabUtf8 := { remaining := 1, value := b % 32, minimum := 128 }
    return { state with column := state.column + state.utf8.seen + 1, utf8 := decoder }
  if 224 ≤ b && b ≤ 239 then
    let decoder : TabUtf8 := { remaining := 2, value := b % 16, minimum := 2048 }
    return { state with column := state.column + state.utf8.seen + 1, utf8 := decoder }
  if 240 ≤ b && b ≤ 244 then
    let decoder : TabUtf8 := { remaining := 3, value := b % 8, minimum := 65536 }
    return { state with column := state.column + state.utf8.seen + 1, utf8 := decoder }
  return { state with column := state.column + state.utf8.seen + 1, utf8 := {} }

/-- ASCII consumes one display cell and resolves an incomplete UTF-8 prefix. -/
theorem TabColumnState.advance_ascii (state : TabColumnState) (byte : UInt8)
    (unicode : Bool) (h : byte.toNat < 128) :
    state.advance byte unicode =
      { state with column := state.column + state.utf8.seen + 1, utf8 := {} } := by
  simp [TabColumnState.advance, h]

/-- Select Unicode display width rules from the process locale once per applet. -/
def tabUnicodeLocale : IO Bool := do
  let all ← IO.getEnv "LC_ALL"
  let ctype ← IO.getEnv "LC_CTYPE"
  let lang ← IO.getEnv "LANG"
  let locale := (([all, ctype, lang] : List (Option String)).filterMap id).find? (!·.isEmpty)
    |>.getD "C"
  return locale != "C" && locale != "POSIX"

end Lutils
