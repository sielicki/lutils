/- Mkdir utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- `mkdir [-p] DIRECTORY...` -/
def runMkdir : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "mkdir [OPTION]... DIRECTORY..." args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut parents := false
  let mut dirsRev : List String := []
  for a in before do
    if a == "-p" || a == "--parents" then
      parents := true
    else if a == "-v" || a == "--verbose" then
      pure ()
    else if a.startsWith "-" && a.length > 1 then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    else
      dirsRev := a :: dirsRev
  let dirs := dirsRev.reverse ++ positional
  if dirs.isEmpty then
    reportError prog "missing operand"
    IO.eprintln s!"Usage: mkdir [OPTION]... DIRECTORY..."
    return exitFail
  let mut status := exitOk
  for d in dirs do
    try
      if parents then IO.FS.createDirAll d
      else IO.FS.createDir d
    catch e =>
      reportError prog s!"cannot create directory '{d}': {describeError e}"
      status := exitFail
  return status

/-- Multicall registration for `mkdir`. -/
abbrev MkdirApplet := AppletTag "mkdir" runMkdir

end Lutils
