/- Sum utility implementation. -/
import Lutils.Shared.LegacySum

namespace Lutils

open LegacySum

/-- `sum [-r | -s] [FILE]...`: BSD checksum and 1024-byte block count by
default; `-s` selects the System V checksum and 512-byte blocks. -/
def runSum : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "sum [OPTION]... [FILE]..." args then
    return code
  let mut sysv := false
  let mut files : List String := []
  let (before, positional) := splitDoubleDash args
  for arg in before do
    if arg == "-" || !arg.startsWith "-" then
      files := files ++ [arg]
    else if arg.startsWith "--" then
      match arg with
      | "--sysv" => sysv := true
      | _ =>
          reportError prog s!"unrecognized option '{arg}'"
          IO.eprintln s!"Try '{prog} --help' for more information."
          return exitFail
    else
      for c in (arg.drop 1).toString.toList do
        match c with
        | 'r' => sysv := false
        | 's' => sysv := true
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            IO.eprintln s!"Try '{prog} --help' for more information."
            return exitFail
  let allFiles := files ++ positional
  let mut good := true
  for file in operandsOrStdin allFiles do
    try
      let data ← readOperandBytes file
      let name := if allFiles.isEmpty then none else some file
      putStr (if sysv then renderSysv data name false else renderBsd data name false)
    catch e =>
      reportFileError prog file e
      good := false
  return if good then exitOk else exitFail

end Lutils
