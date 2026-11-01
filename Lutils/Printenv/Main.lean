/- Printenv utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

inductive PrintenvParseMode where
  | options
  | variables
  deriving BEq

/-- Read `/proc/self/environ` (Linux) to enumerate the environment, which
Lean's `IO.getEnv` alone cannot do. -/
def readEnviron : IO (Option (List String)) := do
  try
    let bytes ← IO.FS.readBinFile "/proc/self/environ"
    let text := decodeLossy bytes
    let entries := text.splitToList (· == '\x00') |>.filter (!·.isEmpty)
    return some entries
  catch _ =>
    return none

/-- `printenv [-0] [VARIABLE]...` -/
def runPrintenv : Applet := fun prog args => do
  let mut mode := PrintenvParseMode.options
  let mut nullTerm := false
  let mut varsRev : List String := []
  for a in args do
    if mode == .variables then
      varsRev := a :: varsRev
    else if a == "--" then
      mode := .variables
    else if a == "--help" then
      return ← helpAndExit prog "printenv [OPTION]... [VARIABLE]..."
    else if a == "--version" then
      return ← versionAndExit prog
    else if a == "-0" || a == "--null" then
      nullTerm := true
    else if a.startsWith "-" && a != "-" then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    else
      varsRev := a :: varsRev
      mode := .variables
  let vars := varsRev.reverse
  let sep := if nullTerm then "\x00" else "\n"
  if vars.isEmpty then
    match ← readEnviron with
    | some entries =>
        for entry in entries do
          putStr (entry ++ sep)
        return exitOk
    | none =>
        reportError prog "cannot enumerate the environment on this platform (no /proc/self/environ)"
        return exitFail
  else
    let mut status := exitOk
    for var in vars do
      match ← IO.getEnv var with
      | some value => putStr (value ++ sep)
      | none => status := exitFail
    return status

end Lutils
