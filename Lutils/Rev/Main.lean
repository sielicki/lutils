/- Rev utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- Reverse Unicode characters without materializing a character list. -/
def reverseChars (s : String) : String :=
  s.foldr (fun c acc => acc.push c) ""

private theorem foldrPush_eq_ofListReverse (xs : List Char) :
    xs.foldr (fun c acc => acc.push c) "" = String.ofList xs.reverse := by
  induction xs with
  | nil => simp
  | cons c cs ih =>
      simp only [List.foldr_cons, List.reverse_cons]
      rw [ih, String.ofList_append, ← String.singleton_eq_ofList,
          String.append_singleton]

/-- The direct scan agrees with the earlier list-based character reversal. -/
theorem reverseChars_eq_ofListReverse (s : String) :
    reverseChars s = String.ofList s.toList.reverse := by
  simp only [reverseChars, String.foldr_eq_foldr_toList,
             foldrPush_eq_ofListReverse]

/-- Reversing the characters twice restores the line. -/
theorem reverseChars_involutive (s : String) :
    reverseChars (reverseChars s) = s := by
  simp [reverseChars_eq_ofListReverse]

/-- `rev [FILE]...`: reverse each line. -/
def runRev : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "rev [FILE]..." args then return code
  let (before, positional) := splitDoubleDash args
  let mut filesRev : List String := []
  for a in before do
    if a.startsWith "-" && a.length > 1 then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    else
      filesRev := a :: filesRev
  let files := filesRev.reverse ++ positional
  let mut status := exitOk
  for file in operandsOrStdin files do
    try
      let (lines, endsNl) := linesOf (← readOperandText file)
      let out := lines.map reverseChars
      putStr (unlinesOf out endsNl)
    catch e =>
      if isBrokenPipe e then return exitOk
      reportFileError prog file e
      status := exitFail
  return status

end Lutils
