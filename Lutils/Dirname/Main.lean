/- Dirname utility implementation. -/
import Lutils.Shared.Common
import Lutils.Shared.Path

namespace Lutils

/-- The directory part per GNU `dirname`. -/
def dirNameOf (path : String) : String :=
  let trimmed := path.dropEndWhile '/'
  if trimmed.isEmpty then
    if path.isEmpty then "." else "/"
  else
    let beforeBase := trimmed.dropEndWhile (· != '/')
    if beforeBase.isEmpty then "."
    else
      let dir := beforeBase.dropEndWhile '/'
      if dir.isEmpty then "/" else dir.copy

/-- Except for root, `dirname` leaves no trailing slash. -/
theorem dirNameOf_normalized (path : String) :
    dirNameOf path = "/" ∨ (dirNameOf path).endsWith '/' = false := by
  unfold dirNameOf
  by_cases ht : (path.dropEndWhile '/').isEmpty = true
  · by_cases hp : path.isEmpty = true
    · right
      simpa [ht, hp] using
        (show ".".endsWith '/' = false by simp [String.endsWith_char_eq_getLast?])
    · left
      simp [ht, hp]
  · let trimmed := path.dropEndWhile '/'
    by_cases hb : (trimmed.dropEndWhile (· != '/')).isEmpty = true
    · right
      simpa [trimmed, ht, hb] using
        (show ".".endsWith '/' = false by simp [String.endsWith_char_eq_getLast?])
    · let beforeBase := trimmed.dropEndWhile (· != '/')
      by_cases hd : (beforeBase.dropEndWhile '/').isEmpty = true
      · left
        simp [trimmed, beforeBase, ht, hb, hd]
      · right
        simp [trimmed, beforeBase, ht, hb, hd, String.Slice.endsWith_copy]

/-- `dirname [-z] NAME...` -/
def runDirname : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "dirname [OPTION] NAME..." args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut zero := false
  let mut namesRev : List String := []
  for a in before do
    if a == "-z" || a == "--zero" then
      zero := true
    else if a.startsWith "-" && a.length > 1 then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    else
      namesRev := a :: namesRev
  let names := namesRev.reverse ++ positional
  if names.isEmpty then
    reportError prog "missing operand"
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  for name in names do
    putStr (dirNameOf name ++ if zero then "\x00" else "\n")
  return exitOk

/-- Multicall registration for `dirname`. -/
abbrev DirnameApplet := AppletTag "dirname" runDirname

end Lutils
