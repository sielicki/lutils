/- Realpath utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- Lexical absolutisation used by `realpath -m`: absolutise against the
working directory and normalise `.`/`..` textually. -/
def absolutiseLexical (path : String) : IO String := do
  let cwd ← IO.Process.getCurrentDir
  let abs : System.FilePath :=
    if path.startsWith "/" then path
    else cwd / path
  let mut reversedParts : List String := []
  for part in abs.components do
    if part == "." || part.isEmpty then
      continue
    else if part == ".." then
      reversedParts := reversedParts.drop 1
    else if part == "/" then
      continue
    else
      reversedParts := part :: reversedParts
  return "/" ++ "/".intercalate reversedParts.reverse

/-- `realpath [-m] [-z] PATH...`: canonical paths via `IO.FS.realPath`;
`-m` allows missing components (lexical normalisation). -/
def runRealpath : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "realpath [OPTION]... FILE..." args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut noMissing := false
  let mut zero := false
  let mut pathsRev : List String := []
  for a in before do
    if a == "-m" || a == "--canonicalize-missing" then
      noMissing := true
    else if a == "-e" || a == "--canonicalize-existing" then
      pure ()
    else if a == "-z" || a == "--zero" then
      zero := true
    else if a == "-s" || a == "--no-symlinks" then
      noMissing := true  -- closest available behaviour without FFI stat
    else if a.startsWith "-" && a.length > 1 then
      reportError prog s!"invalid option -- '{a}'"
      return exitFail
    else
      pathsRev := a :: pathsRev
  let paths := pathsRev.reverse ++ positional
  if paths.isEmpty then
    reportError prog "missing operand"
    IO.eprintln s!"Usage: realpath [OPTION]... FILE..."
    return exitFail
  let term := if zero then "\x00" else "\n"
  let mut status := exitOk
  for path in paths do
    try
      let resolved :=
        if noMissing then absolutiseLexical path
        else toString <$> IO.FS.realPath path
      putStr ((← resolved) ++ term)
    catch e =>
      reportFileError prog path e
      status := exitFail
  return status

/-- Multicall registration for `realpath`. -/
abbrev RealpathApplet := AppletTag "realpath" runRealpath

end Lutils
