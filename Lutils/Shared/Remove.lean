/- Shared recursive remove support. -/
import Lutils.Shared.Common

namespace Lutils

open System (FilePath)

/-- Confirm interactively (`rm -i`); anything but y/es means no. -/
def confirm (question : String) : IO Bool := do
  let stderr ← IO.getStderr
  stderr.putStr question
  stderr.flush
  let stdin ← IO.getStdin
  let answer := (← stdin.getLine).trimAscii.copy
  return answer == "y" || answer == "Y" || answer == "yes"

/-- Ask only when interactive. The confirmation must be bound conditionally:
a `(← confirm ...)` nested inside `!interactive || ...` is hoisted by the
`do` elaborator and runs even when its result is short-circuited away. -/
def confirmIf (interactive : Bool) (question : String) : IO Bool :=
  if interactive then confirm question else pure true

/-- Print the GNU `rm -v` line for a removed file or directory. -/
def reportRemoved (verbose isDir : Bool) (path : FilePath) : IO Unit := do
  if verbose then
    IO.println (if isDir then s!"removed directory '{path}'" else s!"removed '{path}'")

partial def removeRecursive (prog : String) (force interactive verbose : Bool)
    (path : FilePath) : IO UInt32 := do
  match ← path.symlinkMetadata.toBaseIO with
  | .error e =>
      if force then
        if let .noFileOrDirectory .. := e then return exitOk
      reportError prog s!"cannot remove '{path}': {describeError e}"
      return exitFail
  | .ok md =>
      try
        if md.type == .dir then
          if !(← confirmIf interactive s!"{prog}: descend into directory '{path}'? ") then
            return exitOk
          let mut status := exitOk
          for entry in ← path.readDir do
            let code ← removeRecursive prog force interactive verbose entry.path
            if code != exitOk then status := exitFail
          if (← confirmIf interactive s!"{prog}: remove directory '{path}'? ") then
            IO.FS.removeDir path
            reportRemoved verbose true path
          return status
        else
          if (← confirmIf interactive s!"{prog}: remove '{path}'? ") then
            IO.FS.removeFile path
            reportRemoved verbose false path
          return exitOk
      catch e =>
        if force then
          if let .noFileOrDirectory .. := e then return exitOk
        reportError prog s!"cannot remove '{path}': {describeError e}"
        return exitFail

end Lutils
