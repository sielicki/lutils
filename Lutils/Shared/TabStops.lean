/- Shared tab-stop types and parsing for expand and unexpand. -/
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

/-- Explicit lists beyond their last stop use one column. -/
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

/-- Whether a listed specification still has a genuine tab stop ahead. -/
def ExpandStops.hasNext (stops : ExpandStops) (column : Nat) : Bool :=
  match stops with
  | .periodic _ => true
  | .listed values continuation =>
      (values.find? (· > column)).isSome || continuation.isSome

theorem ExpandStops.periodic_next_gt (width : TabWidth) (column : Nat) :
    column < (ExpandStops.periodic width).next column :=
  width.next_gt column

def parseTabWidth (value : String) : Except String TabWidth :=
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

end Lutils
