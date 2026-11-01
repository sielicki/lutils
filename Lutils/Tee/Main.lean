/- Tee utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- `tee [-a] [FILE]...`: copy stdin to stdout and each file. -/
def runTee : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "tee [OPTION]... [FILE]..." args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut append := false
  let mut filesRev : List String := []
  for a in before do
    if a == "-a" || a == "--append" then
      append := true
    else if a == "-i" || a == "--ignore-interrupts" then
      pure ()
    else if a.startsWith "-" && a.length > 1 then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    else
      filesRev := a :: filesRev
  let files := filesRev.reverse ++ positional
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let mut handlesRev : List (String × IO.FS.Handle) := []
  let mut status := exitOk
  for file in files do
    try
      let h ← IO.FS.Handle.mk file (if append then .append else .write)
      handlesRev := (file, h) :: handlesRev
    catch e =>
      reportFileError prog file e
      status := exitFail
  let handles := handlesRev.reverse
  let mut looping := true
  while looping do
    try
      let chunk ← stdin.read 8192
      if chunk.isEmpty then
        looping := false
      else
        stdout.write chunk
        stdout.flush
        for (_, h) in handles do
          h.write chunk
    catch e =>
      if isBrokenPipe e then
        looping := false
      else
        throw e
  for (_, h) in handles do
    try h.flush catch _ => pure ()
  return status

end Lutils
