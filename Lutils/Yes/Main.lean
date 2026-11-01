/- Yes utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

partial def yesLoop (block : ByteArray) : IO Unit := do
  writeStdout block
  yesLoop block

/-- `yes [STRING]...`: repeat the joined string (default `y`) forever. -/
def runYes : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "yes [STRING]..." args then return code
  let (before, after) := splitDoubleDash args
  for a in before do
      if a.startsWith "-" && a != "-" then
        reportError prog s!"invalid option -- '{a}'"
        IO.eprintln s!"Usage: yes [STRING]..."
        return exitFail
  yesBody (before ++ after)
where
  yesBody (words : List String) : IO UInt32 := do
    let line := if words.isEmpty then "y" else " ".intercalate words
    -- One block of 128 lines keeps writes large enough to be fast.
    let block := String.toUTF8 ("".intercalate (List.replicate 128 (line ++ "\n")))
    try
      yesLoop block
      return exitOk
    catch e =>
      -- GNU yes dies of SIGPIPE; Lean surfaces that as an IO error instead.
      return if isBrokenPipe e then exitOk else exitFail

/-- Multicall registration for `yes`. -/
abbrev YesApplet := AppletTag "yes" runYes

end Lutils
