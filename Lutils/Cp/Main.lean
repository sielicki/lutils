/- Cp utility implementation. -/
import Lutils.Shared.Common
import Lutils.Shared.Copy

namespace Lutils

open System (FilePath)

/-- `cp [-rRf] SOURCE... DEST` (subset: no symlinks/preserve yet). -/
def runCp : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "cp [OPTION]... SOURCE... DEST" args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut recursive := false
  let mut filesRev : List String := []
  for a in before do
    if a == "-" then
      filesRev := a :: filesRev
    else if a.startsWith "--" then
      match a with
      | "--recursive" => recursive := true
      | "--force" => pure ()
      | "--verbose" => pure ()
      | "--interactive" => pure ()
      | "--archive" => recursive := true
      | _ =>
          reportError prog s!"invalid option -- '{a}'"
          return exitFail
    else if a.startsWith "-" && a.length > 1 then
      for c in a.toList.drop 1 do
        match c with
        | 'r' | 'R' | 'a' => recursive := true
        | 'f' | 'i' | 'v' | 'n' | 'u' => pure ()
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            return exitFail
    else
      filesRev := a :: filesRev
  let files := filesRev.reverse ++ positional
  match files.reverse with
  | [] =>
      reportError prog "missing file operand"
      IO.eprintln s!"Usage: cp [OPTION]... SOURCE... DEST"
      return exitFail
  | [src] =>
      reportError prog s!"missing destination file operand after '{src}'"
      return exitFail
  | dst :: reversedSources =>
      let srcs := reversedSources.reverse
      let dstPath : FilePath := dst
      let dstIsDir ← dstPath.isDir
      if srcs.length > 1 && !dstIsDir then
        reportError prog s!"target '{dst}' is not a directory"
        return exitFail
      let mut status := exitOk
      for src in srcs do
        let p : FilePath := src
        match ← p.symlinkMetadata.toBaseIO with
        | .error e =>
            reportError prog s!"cannot stat '{src}': {describeError e}"
            status := exitFail
        | .ok md =>
            if md.type == .dir && !recursive then
              reportError prog s!"-r not specified; omitting directory '{src}'"
              status := exitFail
            else
              let target ← copyDest p dstPath
              match ← copyConflict? p target md.type with
              | some .sameFile =>
                  reportError prog s!"'{src}' and '{target}' are the same file"
                  status := exitFail
              | some .insideSource =>
                  reportError prog s!"cannot copy '{src}' into itself, '{target}'"
                  status := exitFail
              | none =>
                  let code ← copyRecursive prog p target
                  if code != exitOk then status := exitFail
      return status

/-- Multicall registration for `cp`. -/
abbrev CpApplet := AppletTag "cp" runCp

end Lutils
