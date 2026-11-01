/-
Multicall entry point, busybox-style:

* Invoked through a symlink whose name is an applet (`cat`, `ls`, ...):
  run that applet with all arguments.
* Invoked as `lutils APPLET [ARGS]...`: run the named applet.
* `lutils --list` prints every applet name (the Nix package uses this to
  lay down the applet symlinks, keeping a single source of truth).

`argv[0]` recovery: Lean's `main` arguments exclude `argv[0]`, and
`IO.appPath` may resolve symlinks. On Linux we therefore read the real
`argv[0]` from `/proc/self/cmdline`, falling back to `IO.appPath`'s file
name elsewhere.
-/
import Lutils

open Lutils

/-- The name this process was invoked as (base name of `argv[0]`). -/
def invokedName : IO String := do
  try
    let bytes ← IO.FS.readBinFile "/proc/self/cmdline"
    let first := decodeLossy (bytes.extract 0 (nulIndex bytes))
    if first.isEmpty then
      fallback
    else
      return baseNameOf first
  catch _ =>
    fallback
where
  fallback : IO String := do
    let path ← IO.appPath
    return (path.fileName.getD "lutils")
  nulIndex (b : ByteArray) : Nat :=
    match b.toList.idxOf? 0 with
    | some i => i
    | none => b.size

def printUsage : IO Unit := do
  IO.eprintln s!"lutils {Lutils.version} - Unix utilities in Lean (multicall binary)"
  IO.eprintln ""
  IO.eprintln "Usage: lutils APPLET [ARGS]..."
  IO.eprintln "   or: APPLET [ARGS]...         (when invoked via an applet symlink)"
  IO.eprintln ""
  IO.eprintln "Options:"
  IO.eprintln "  --list       print applet names, one per line"
  IO.eprintln "  --help       show this help"
  IO.eprintln "  --version    show version"
  IO.eprintln ""
  IO.eprintln s!"Applets: {", ".intercalate appletNames}"

def main (args : List String) : IO UInt32 := do
  let name ← invokedName
  -- Symlink dispatch (anything other than the multicall name itself).
  if name != "lutils" then
    match findApplet name with
    | some applet => return ← applet name args
    | none =>
        -- Unknown argv[0]: fall through to first-argument dispatch.
        pure ()
  match args with
  | [] =>
      printUsage
      return exitUsage
  | "--list" :: _ =>
      for appletName in appletNames do
        IO.println appletName
      return exitOk
  | "--help" :: _ | "-h" :: _ =>
      -- Help goes to stdout when explicitly requested.
      IO.println s!"lutils {Lutils.version} - Unix utilities in Lean (multicall binary)"
      IO.println ""
      IO.println "Usage: lutils APPLET [ARGS]..."
      IO.println "   or: APPLET [ARGS]...         (when invoked via an applet symlink)"
      IO.println ""
      IO.println s!"Applets: {", ".intercalate appletNames}"
      IO.println ""
      IO.println "Run 'lutils APPLET --help' for applet-specific usage."
      return exitOk
  | "--version" :: _ =>
      IO.println s!"lutils {Lutils.version}"
      return exitOk
  | appletName :: rest =>
      match findApplet appletName with
      | some applet => return ← applet appletName rest
      | none =>
          IO.eprintln s!"lutils: unknown applet: {appletName}"
          IO.eprintln "Run 'lutils --list' to see available applets."
          return exitFail
