/- Pwd utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

inductive PwdMode where
  | logical
  | physical
  deriving BEq

/-- `pwd [-L | -P]`: print the working directory. `-L` (default) prefers a
sane `$PWD`; `-P` always uses the physical directory. -/
def runPwd : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "pwd [-LP]" args then return code
  let (opts, pos) := splitDoubleDash args
  let mut mode := PwdMode.logical
  let mut hasOperand := !pos.isEmpty
  for a in opts do
    if a == "-P" || a == "--physical" then
      mode := .physical
    else if a == "-L" || a == "--logical" then
      mode := .logical
    else if a.startsWith "-" && a.length > 1 then
      reportError prog s!"invalid option -- '{a}'"
      IO.eprintln s!"Usage: pwd [-LP]"
      return exitFail
    else
      hasOperand := true
  if hasOperand then
    reportError prog "ignoring non-option arguments"
  try
    let dir ←
      if mode == .physical then
        pure (toString (← IO.Process.getCurrentDir))
      else
        match ← IO.getEnv "PWD" with
        | some pwd =>
            let sane ← if pwd.startsWith "/" then System.FilePath.isDir pwd else pure false
            if sane then
              pure pwd
            else
              pure (toString (← IO.Process.getCurrentDir))
        | none => pure (toString (← IO.Process.getCurrentDir))
    IO.println dir
    return exitOk
  catch e =>
    reportError prog (describeError e)
    return exitFail

end Lutils
