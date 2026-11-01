/- Rm utility implementation. -/
import Lutils.Shared.Common
import Lutils.Shared.Remove

namespace Lutils

open System (FilePath)

/-- `rm [-rfid] FILE...` (root preservation on by default). -/
def runRm : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "rm [OPTION]... FILE..." args then
    return code
  let mut recursive := false
  let mut force := false
  let mut interactive := false
  let mut dirOnly := false
  let mut verbose := false
  let mut filesRev : List String := []
  let (before, positional) := splitDoubleDash args
  for a in before do
    if a == "-" then
      filesRev := a :: filesRev
    else if a.startsWith "--" then
      match a with
      | "--recursive" => recursive := true
      | "--force" => force := true
      | "--interactive" => interactive := true
      | "--dir" => dirOnly := true
      | "--preserve-root" => pure ()
      | "--no-preserve-root" => pure ()  -- still refused below; safer default
      | "--verbose" => verbose := true
      | "--one-file-system" => pure ()
      | _ =>
          reportError prog s!"invalid option -- '{a}'"
          return exitFail
    else if a.startsWith "-" && a.length > 1 then
      for c in a.toList.drop 1 do
        match c with
        | 'r' | 'R' => recursive := true
        | 'f' => do force := true; interactive := false
        | 'i' => interactive := true
        | 'd' => dirOnly := true
        | 'v' => verbose := true
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            return exitFail
    else
      filesRev := a :: filesRev
  let files := filesRev.reverse ++ positional
  if files.isEmpty then
    if force then return exitOk
    reportError prog "missing operand"
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  let mut status := exitOk
  for f in files do
    if f == "/" || f == "." || f == ".." then
      reportError prog s!"refusing to remove '{f}'"
      status := exitFail
      continue
    let p : FilePath := f
    match ← p.symlinkMetadata.toBaseIO with
    | .error e =>
        if !force then
          reportError prog s!"cannot remove '{f}': {describeError e}"
          status := exitFail
    | .ok md =>
        if md.type == .dir && !recursive && !dirOnly then
          reportError prog s!"cannot remove '{f}': Is a directory"
          status := exitFail
        else if recursive then
          let code ← removeRecursive prog force interactive verbose p
          if code != exitOk then status := exitFail
        else if md.type == .dir then
          try
            if (← confirmIf interactive s!"{prog}: remove directory '{f}'? ") then
              IO.FS.removeDir p
              reportRemoved verbose true p
          catch e =>
            reportError prog s!"cannot remove '{f}': {describeError e}"
            status := exitFail
        else
          try
            if (← confirmIf interactive s!"{prog}: remove '{f}'? ") then
              IO.FS.removeFile p
              reportRemoved verbose false p
          catch e =>
            if !force then
              reportError prog s!"cannot remove '{f}': {describeError e}"
              status := exitFail
  return status

/-- Multicall registration for `rm`. -/
abbrev RmApplet := AppletTag "rm" runRm

end Lutils
