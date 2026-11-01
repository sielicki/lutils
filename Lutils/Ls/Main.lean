/- Ls utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

open System (FilePath)

/-- Sort paths/strings with plain byte-wise (code point) order. -/
def sortStrings (xs : List String) : List String :=
  xs.mergeSort (· ≤ ·)

/-- Escape a filename the way `ls` does for terminal output: controls as `?`.
Kept minimal: control characters become `?`. -/
def displayName (tty : Bool) (name : String) : String :=
  if !tty then name
  else String.ofList (name.toList.map fun c =>
    if c.toNat < 32 && c != '\t' then '?' else c)

inductive LsSort where
  | name
  | time
  | size

/-- Bound the number of columns by the number of names. More columns cannot
display anything and otherwise make a very wide `COLUMNS` value costly. -/
def columnCount (entryCount maxLen width : Nat) : Nat :=
  min entryCount (max 1 (width / (maxLen + 2)))

theorem columnCount_le_entries (entryCount maxLen width : Nat) :
    columnCount entryCount maxLen width ≤ entryCount := by
  exact Nat.min_le_left _ _

theorem columnCount_pos {entryCount : Nat} (h : 0 < entryCount)
    (maxLen width : Nat) : 0 < columnCount entryCount maxLen width := by
  exact Nat.lt_min.mpr ⟨h, Nat.lt_of_lt_of_le (by decide : 0 < 1)
    (Nat.le_max_left _ _)⟩

theorem columnCount_eq_uncapped {entryCount maxLen width : Nat}
    (h : max 1 (width / (maxLen + 2)) ≤ entryCount) :
    columnCount entryCount maxLen width = max 1 (width / (maxLen + 2)) := by
  exact Nat.min_eq_right h

theorem columnCount_eq_entries {entryCount maxLen width : Nat}
    (h : entryCount ≤ max 1 (width / (maxLen + 2))) :
    columnCount entryCount maxLen width = entryCount := by
  exact Nat.min_eq_left h

/-- `ls` options (subset). -/
structure LsOpts where
  all : Bool := false
  almostAll : Bool := false
  onePerLine : Bool := false
  classify : Bool := false
  directory : Bool := false
  recursive : Bool := false
  reverse : Bool := false
  sortBy : LsSort := .name
  files : List String := []

def parseLs (prog : String) (args : List String) : IO (Except UInt32 LsOpts) := do
  let mut opts : LsOpts := {}
  let (before, positional) := splitDoubleDash args
  let mut filesRev : List String := []
  for a in before do
    if a == "-" then
      filesRev := a :: filesRev
    else if a.startsWith "--" then
      match a with
      | "--all" => opts := { opts with all := true }
      | "--almost-all" => opts := { opts with almostAll := true }
      | "--classify" => opts := { opts with classify := true }
      | "--directory" => opts := { opts with directory := true }
      | "--recursive" => opts := { opts with recursive := true }
      | "--reverse" => opts := { opts with reverse := true }
      | _ =>
          reportError prog s!"invalid option -- '{a}'"
          IO.eprintln s!"Usage: ls [OPTION]... [FILE]..."
          return .error exitFail
    else if a.startsWith "-" && a.length > 1 then
      for c in a.toList.drop 1 do
        match c with
        | 'a' => opts := { opts with all := true }
        | 'A' => opts := { opts with almostAll := true }
        | '1' => opts := { opts with onePerLine := true }
        | 'F' => opts := { opts with classify := true }
        | 'd' => opts := { opts with directory := true }
        | 'R' => opts := { opts with recursive := true }
        | 'r' => opts := { opts with reverse := true }
        | 't' => opts := { opts with sortBy := .time }
        | 'S' => opts := { opts with sortBy := .size }
        | 'C' => opts := { opts with onePerLine := false }
        | 'l' =>
            reportError prog "option -l is not supported yet (needs FFI stat for mode/owner)"
            return .error exitFail
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            IO.eprintln s!"Usage: ls [OPTION]... [FILE]..."
            return .error exitFail
    else
      filesRev := a :: filesRev
  opts := { opts with files := filesRev.reverse ++ positional }
  return .ok opts

/-- Metadata, returning `none` instead of throwing. -/
def metadata? (p : FilePath) : IO (Option IO.FS.Metadata) := do
  match ← p.metadata.toBaseIO with
  | .ok m => return some m
  | .error _ => return none

/-- `-F` classification suffix for a path (best effort without mode bits). -/
def classifySuffix (md : IO.FS.Metadata) : String :=
  match md.type with
  | .dir => "/"
  | .symlink => "@"
  | .file => ""  -- No execute bit in Metadata; treat regular files as plain.
  | .other => ""

structure LsEntry where
  name : String
  path : FilePath
  mtime : Int
  size : Nat

/-- Order directory entries per `ls` sorting options. -/
def orderEntries (opts : LsOpts) (entries : List (String × FilePath)) :
    IO (List (String × FilePath)) := do
  if let .name := opts.sortBy then
    let sorted := entries.mergeSort (fun a b => a.1 ≤ b.1)
    return if opts.reverse then sorted.reverse else sorted
  -- Name ordering needs no metadata; only the time/size paths stat entries.
  let mut decorated : List LsEntry := []
  for (name, path) in entries do
    let md ← metadata? path
    let (mtime, size) := match md with
      | some m => (m.modified.sec, m.byteSize.toNat)
      | none => (0, 0)
    decorated := { name, path, mtime, size } :: decorated
  let sorted :=
    match opts.sortBy with
    | .time => decorated.mergeSort (fun a b =>
        if a.mtime != b.mtime then a.mtime > b.mtime else a.name ≤ b.name)
    | .size => decorated.mergeSort (fun a b =>
        if a.size != b.size then a.size > b.size else a.name ≤ b.name)
    | .name => decorated.mergeSort (fun a b => a.name ≤ b.name)
  let sorted := if opts.reverse then sorted.reverse else sorted
  return sorted.map fun entry => (entry.name, entry.path)

/-- Format entries in columns fitting `width`, GNU-style down-columns order. -/
def formatColumns (names : List String) (width : Nat) : String := Id.run do
  if names.isEmpty then
    return ""
  let maxLen := names.foldl (fun m s => max m s.length) 0
  let colWidth := maxLen + 2
  let entryCount := names.length
  let cols := columnCount entryCount maxLen width
  if cols <= 1 then
    return unlinesOf names true
  let rows := (entryCount + cols - 1) / cols
  let arr := names.toArray
  let mut linesRev : List String := []
  for r in List.range rows do
    let mut cellsRev : List String := []
    for c in List.range cols do
      let idx := c * rows + r
      if h : idx < arr.size then
        let cell := arr[idx]
        cellsRev := (
          if c + 1 == cols || (c + 1) * rows + r >= arr.size then cell
          else cell ++ String.ofList (List.replicate (colWidth - cell.length) ' ')) :: cellsRev
    linesRev := String.join cellsRev.reverse :: linesRev
  return unlinesOf linesRev.reverse true

/-- Render file names and optional classification suffixes in entry order. -/
def displayEntries (opts : LsOpts) (tty : Bool)
    (entries : List (String × FilePath)) : IO (List String) := do
  let mut namesRev : List String := []
  for (name, path) in entries do
    let suffix ←
      if opts.classify then do
        match ← path.symlinkMetadata.toBaseIO with
        | .ok md => pure (classifySuffix md)
        | .error _ => pure ""
      else pure ""
    namesRev := (displayName tty name ++ suffix) :: namesRev
  return namesRev.reverse

partial def listDir (prog : String) (opts : LsOpts) (tty : Bool) (width : Nat)
    (path : FilePath) (showHeader : Bool) : IO UInt32 := do
  try
    let raw ← path.readDir
    if showHeader then
      putStr s!"{path}:\n"
    let mut entriesRev : List (String × FilePath) :=
      if opts.all then [("..", path.parent.getD path), (".", path)] else []
    for entry in raw do
      let name := entry.fileName
      if !opts.all && !opts.almostAll && name.startsWith "." then
        continue
      entriesRev := (name, entry.path) :: entriesRev
    let ordered ← orderEntries opts entriesRev.reverse
    let names ← displayEntries opts tty ordered
    if opts.onePerLine || !tty then
      if !names.isEmpty then putStr (unlinesOf names true)
    else
      putStr (formatColumns names width)
    if opts.recursive then
      let mut status := exitOk
      for (name, p) in ordered do
        if name == "." || name == ".." then continue
        match ← p.symlinkMetadata.toBaseIO with
        | .ok md =>
            if md.type == .dir then
              putStr "\n"
              let code ← listDir prog opts tty width p true
              if code != exitOk then status := code
        | .error _ => pure ()
      return status
    return exitOk
  catch e =>
    reportFileError prog (toString path) e
    return exitFail

/-- `ls [-aA1CFdRrSt] [FILE]...`: list directory contents (subset; no `-l`). -/
def runLs : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "ls [OPTION]... [FILE]..." args then
    return code
  match ← parseLs prog args with
  | .error code => return code
  | .ok opts =>
      let files := if opts.files.isEmpty then ["."] else opts.files
      let stdout ← IO.getStdout
      let tty ← stdout.isTty
      let width := ((← IO.getEnv "COLUMNS").bind String.toNat?).getD 80
      let mut fileArgsRev : List (String × FilePath) := []
      let mut dirArgsRev : List String := []
      let mut status := exitOk
      for f in sortStrings files do
        let p : FilePath := f
        match ← p.metadata.toBaseIO with
        | .error e =>
            reportError prog s!"cannot access '{f}': {describeError e}"
            status := exitFail
        | .ok md =>
            if md.type == .dir && !opts.directory then
              dirArgsRev := f :: dirArgsRev
            else
              fileArgsRev := (f, p) :: fileArgsRev
      let fileArgs := fileArgsRev.reverse
      let dirArgs := dirArgsRev.reverse
      -- Non-directory operands first, as GNU does.
      if !fileArgs.isEmpty then
        let ordered ← orderEntries opts fileArgs
        let names ← displayEntries opts tty ordered
        if opts.onePerLine || !tty then putStr (unlinesOf names true)
        else putStr (formatColumns names width)
      let multi := files.length > 1 || opts.recursive || !fileArgs.isEmpty
      let mut shown := 0
      for d in dirArgs do
        if multi && (!fileArgs.isEmpty || shown > 0) then
          putStr "\n"
        shown := shown + 1
        let path : FilePath := d
        let code ← listDir prog opts tty width path multi
        if code != exitOk then status := exitFail
      return status

/-- Multicall registration for `ls`. -/
abbrev LsApplet := AppletTag "ls" runLs

end Lutils
