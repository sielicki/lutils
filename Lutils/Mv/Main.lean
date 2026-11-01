/- Mv utility implementation. -/
import Lutils.Shared.Common
import Lutils.Shared.Copy
import Lutils.Shared.Remove

namespace Lutils

open System (FilePath)

/-- `mv [-f] SOURCE... DEST`: `rename` with copy+remove fallback (EXDEV). -/
def runMv : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "mv [OPTION]... SOURCE... DEST" args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut filesRev : List String := []
  for a in before do
    if a == "-" then
      filesRev := a :: filesRev
    else if a.startsWith "--" then
      match a with
      | "--force" | "--verbose" | "--interactive" | "--no-clobber" | "--update" => pure ()
      | _ =>
          reportError prog s!"invalid option -- '{a}'"
          return exitFail
    else if a.startsWith "-" && a.length > 1 then
      for c in a.toList.drop 1 do
        match c with
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
      IO.eprintln s!"Usage: mv [OPTION]... SOURCE... DEST"
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
        let srcPath : FilePath := src
        let target ← copyDest srcPath dstPath
        try
          IO.FS.rename srcPath target
        catch e =>
          -- EXDEV: rename cannot cross filesystems; copy then remove the source.
          match e with
          | .unsupportedOperation 18 _ =>
              let code ← copyRecursive prog srcPath target
              if code == exitOk then
                let rc ← removeRecursive prog false false false srcPath
                if rc != exitOk then status := exitFail
              else
                status := exitFail
          | _ =>
              reportError prog s!"cannot move '{src}' to '{target}': {describeError e}"
              status := exitFail
      return status

end Lutils
