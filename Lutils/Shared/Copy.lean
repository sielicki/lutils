/- Shared copy operations. -/
import Lutils.Shared.Common
import Lutils.Shared.Path

namespace Lutils

open System (FilePath)

/-- Resolve existing path components while retaining missing destination components.
This lets us check a prospective copy target before creating it. -/
def prospectiveRealPath (path : FilePath) : IO FilePath := do
  let cwd ← IO.Process.getCurrentDir
  let absolute := if path.isAbsolute then path else cwd / path
  let mut resolved : FilePath := "/"
  for part in absolute.components do
    if part.isEmpty || part == "." then
      continue
    if part == ".." then
      resolved := resolved.parent.getD resolved
    else
      let next := resolved / part
      match ← (IO.FS.realPath next).toBaseIO with
      | .ok canonical => resolved := canonical
      | .error _ => resolved := next
  return resolved

inductive CopyConflict where
  | sameFile
  | insideSource

/-- The path-safety decision is pure once both paths have been resolved. -/
def classifyCopyTarget (source target : FilePath) (kind : IO.FS.FileType) :
    Option CopyConflict :=
  if source == target then some .sameFile
  else
    match kind with
    | .dir =>
        if source.components.isPrefixOf target.components then some .insideSource
        else none
    | _ => none

/-- A rejected identical target cannot be mistaken for a safe copy. -/
theorem classifyCopyTarget_self (source : FilePath) (kind : IO.FS.FileType) :
    classifyCopyTarget source source kind = some .sameFile := by
  simp [classifyCopyTarget]

/-- A safe result certifies that the source and destination differ. -/
theorem classifyCopyTarget_none_ne (source target : FilePath)
    (kind : IO.FS.FileType)
    (h : classifyCopyTarget source target kind = none) : source ≠ target := by
  intro same
  subst target
  simp [classifyCopyTarget_self] at h

/-- Every proper descendant of a directory source is rejected. -/
theorem classifyCopyTarget_dir_descendant (source target : FilePath)
    (different : (source == target) = false)
    (inside : source.components.isPrefixOf target.components = true) :
    classifyCopyTarget source target .dir = some .insideSource := by
  simp [classifyCopyTarget, different, inside]

/-- Directory copies classified as safe do not recurse into the source. -/
theorem classifyCopyTarget_none_not_inside (source target : FilePath)
    (h : classifyCopyTarget source target .dir = none) :
    source.components.isPrefixOf target.components = false := by
  by_cases same : source == target
  · simp [classifyCopyTarget, same] at h
  · cases inside : source.components.isPrefixOf target.components with
    | false => rfl
    | true => simp [classifyCopyTarget, same, inside] at h

/-- Detect copies that would overwrite a source or recurse into it. -/
def copyConflict? (src dst : FilePath) (kind : IO.FS.FileType) :
    IO (Option CopyConflict) := do
  let source ← IO.FS.realPath src
  let target ← prospectiveRealPath dst
  return classifyCopyTarget source target kind

/-- Copy one regular file in bounded chunks, overwriting `dst`. -/
def copyFile (src dst : FilePath) : IO Unit := do
  let input ← IO.FS.Handle.mk src .read
  let output ← IO.FS.Handle.mk dst .write
  let mut reading := true
  while reading do
    let chunk ← input.read 65536
    if chunk.isEmpty then
      reading := false
    else
      output.write chunk
  output.flush

partial def copyRecursive (prog : String) (src dst : FilePath) : IO UInt32 := do
  match ← src.symlinkMetadata.toBaseIO with
  | .error e =>
      reportError prog s!"cannot stat '{src}': {describeError e}"
      return exitFail
  | .ok md =>
      try
        if md.type == .dir then
          IO.FS.createDirAll dst
          let mut status := exitOk
          for entry in ← src.readDir do
            let code ← copyRecursive prog entry.path (dst / entry.fileName)
            if code != exitOk then status := exitFail
          return status
        else if md.type == .file then
          copyFile src dst
          return exitOk
        else
          reportError prog s!"cannot copy special file '{src}' yet (needs FFI for symlinks/devices)"
          return exitFail
      catch e =>
        reportError prog s!"cannot copy '{src}' to '{dst}': {describeError e}"
        return exitFail

/-- Destination for copying `src`: into `dst` when it is a directory. -/
def copyDest (src dst : FilePath) : IO FilePath := do
  if ← dst.isDir then
    return dst / baseNameOf (toString src)
  else
    return dst

end Lutils
