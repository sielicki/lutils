/- Tac utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/- Reverse newline-delimited records while preserving which records have a
terminating newline. -/
def reverseNewlineRecords (input : String) : String :=
  match (input.splitOn "\n").reverse with
  | [] => ""
  | last :: earlier =>
      let finalRecord := if last.isEmpty then [] else [last]
      String.join (finalRecord ++ earlier.map (· ++ "\n"))

/-- `tac [FILE]...`: print each file with its lines reversed. -/
def runTac : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "tac [FILE]..." args then return code
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
      putStr (reverseNewlineRecords (← readOperandText file))
    catch e =>
      if isBrokenPipe e then return exitOk
      reportFileError prog file e
      status := exitFail
  return status

end Lutils
