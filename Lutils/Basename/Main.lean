/- Basename utility implementation. -/
import Lutils.Shared.Common
import Lutils.Shared.Path

namespace Lutils

/-- Remove `suffix` from `name` when present (but never the whole name). -/
def stripSuffix (name suffix : String) : String :=
  if suffix.isEmpty || suffix == name then name
  else
    match name.dropSuffix? suffix with
    | none => name
    | some stem => stem.copy

/-- GNU basename does not erase a name that is exactly its suffix. -/
theorem stripSuffix_self (name : String) : stripSuffix name name = name := by
  simp [stripSuffix]

/-- When stripping changes a name, the result is its exact prefix before the suffix. -/
theorem stripSuffix_sound (name suffix : String) :
    stripSuffix name suffix = name ∨
      ∃ stem, name = stem ++ suffix ∧ stripSuffix name suffix = stem := by
  unfold stripSuffix
  by_cases hguard : suffix.isEmpty || suffix == name
  · left
    simp [hguard]
  · simp only [hguard, Bool.false_eq_true, ↓reduceIte]
    cases hdrop : name.dropSuffix? suffix with
    | none => left; rfl
    | some stem =>
        right
        refine ⟨stem.copy, ?_, rfl⟩
        have hslice : name.toSlice.dropSuffix? suffix = some stem := by
          simpa using hdrop
        simpa using String.Slice.eq_append_of_dropSuffix?_string_eq_some hslice

/-- `basename NAME [SUFFIX]` / `basename [-a] [-s SUFFIX] NAME...` (`-z` too). -/
def runBasename : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "basename NAME [SUFFIX]\n  or:  basename OPTION... NAME..." args then
    return code
  let mut multiple := false
  let mut suffix : Option String := none
  let mut zero := false
  let mut names : List String := []
  let arr := args.toArray
  let mut i := 0
  let mut stopOpts := false
  let mut operandMode := false
  while i < arr.size do
    let some a := arr[i]? | break
    i := i + 1
    if stopOpts || operandMode then
      names := a :: names
    else if a == "--" then
      stopOpts := true
    else if a == "-a" || a == "--multiple" then
      multiple := true
    else if a == "-z" || a == "--zero" then
      zero := true
    else if a == "-za" || a == "-az" then
      zero := true
      multiple := true
    else if a == "-s" || a == "--suffix" then
      match arr[i]? with
      | some value =>
          suffix := some value
          multiple := true
          i := i + 1
      | none =>
          reportError prog "option requires an argument -- 's'"
          return exitFail
    else if a.startsWith "--suffix=" then
      suffix := some (String.ofList (a.toList.drop "--suffix=".length))
      multiple := true
    else if a.startsWith "-s" && a.length > 2 then
      suffix := some (String.ofList (a.toList.drop 2))
      multiple := true
    else if a.startsWith "-" && a.length > 1 && names.isEmpty then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    else
      names := a :: names
      if !multiple && suffix.isNone then
        operandMode := true
  let orderedNames := names.reverse
  match orderedNames with
  | [] =>
      reportError prog "missing operand"
      IO.eprintln s!"Try '{prog} --help' for more information."
      return exitFail
  | _ => pure ()
  if !multiple && suffix.isNone then
    match orderedNames with
    | _ :: _ :: extra :: _ =>
        reportError prog s!"extra operand '{extra}'"
        IO.eprintln s!"Try '{prog} --help' for more information."
        return exitFail
    | _ => pure ()
  let (outputNames, effectiveSuffix) :=
    if multiple || suffix.isSome then
      (orderedNames, suffix)
    else
      match orderedNames with
      | [name, positionalSuffix] => ([name], some positionalSuffix)
      | _ => (orderedNames, suffix)
  let terminator := if zero then "\x00" else "\n"
  for name in outputNames do
    let base := baseNameOf name
    let output := match effectiveSuffix with
      | some s => stripSuffix base s
      | none => base
    putStr (output ++ terminator)
  return exitOk

/-- Multicall registration for `basename`. -/
abbrev BasenameApplet := AppletTag "basename" runBasename

end Lutils
