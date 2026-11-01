/- Rmdir utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

open System (FilePath)

/-- `rmdir [-p] DIRECTORY...`: `-p` also removes (then-empty) ancestors. -/
def runRmdir : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "rmdir [OPTION]... DIRECTORY..." args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut parents := false
  let mut ignoreNonEmpty := false
  let mut dirsRev : List String := []
  for a in before do
    if a == "-p" || a == "--parents" then
      parents := true
    else if a == "--ignore-fail-on-non-empty" then
      ignoreNonEmpty := true
    else if a.startsWith "-" && a.length > 1 then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    else
      dirsRev := a :: dirsRev
  let dirs := dirsRev.reverse ++ positional
  if dirs.isEmpty then
    reportError prog "missing operand"
    IO.eprintln s!"Usage: rmdir [OPTION]... DIRECTORY..."
    return exitFail
  let mut status := exitOk
  for d in dirs do
    let path : FilePath := d
    let targets :=
      if parents then ancestors path else [path]
    for target in targets do
      try
        IO.FS.removeDir target
      catch e =>
        let quiet := ignoreNonEmpty &&
          (match e with | .unsatisfiedConstraints _ _ => true | _ => false)
        if !quiet then
          reportError prog s!"failed to remove '{target}': {describeError e}"
          status := exitFail
        break
  return status
where
  ancestors (path : FilePath) : List FilePath := Id.run do
    let mut reversed : List FilePath := []
    let mut cur : Option FilePath := some path
    while cur.isSome do
      match cur with
      | some p =>
          reversed := p :: reversed
          cur := p.parent
      | none => cur := none
    return reversed.reverse

end Lutils
