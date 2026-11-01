/- Cat utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

inductive CatNumbering where
  | none
  | all
  | nonblank
  deriving BEq

/-- `-b` takes precedence over `-n`, regardless of their order. -/
def CatNumbering.enableAll : CatNumbering → CatNumbering
  | .none => .all
  | mode => mode

/-- Expand `cat -T` and `-E` display forms for one line (without its `\n`). -/
def catDisplayLine (showTabs showEnds : Bool) (line : String) : String :=
  let body :=
    if showTabs then
      String.ofList (line.toList.flatMap fun c => if c == '\t' then ['^', 'I'] else [c])
    else
      line
  if showEnds then body ++ "$" else body

/-- `cat [-bEnsT] [FILE]...` (`-A` = `-ET`, `-e` = `-E`, `-t` = `-T` kept small). -/
def runCat : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "cat [OPTION]... [FILE]..." args then
    return code
  let (before, positional) := splitDoubleDash args
  let mut numbering := CatNumbering.none
  let mut squeeze := false
  let mut showEnds := false
  let mut showTabs := false
  let mut filesRev : List String := []
  for a in before do
    if a == "-" then
      filesRev := a :: filesRev
    else if a.startsWith "--" then
      match a with
      | "--number" => numbering := numbering.enableAll
      | "--number-nonblank" => numbering := .nonblank
      | "--squeeze-blank" => squeeze := true
      | "--show-ends" => showEnds := true
      | "--show-tabs" => showTabs := true
      | "--show-all" => do showEnds := true; showTabs := true
      | _ =>
          reportError prog s!"invalid option -- '{a}'"
          return exitFail
    else if a.startsWith "-" && a.length > 1 then
      for c in a.toList.drop 1 do
        match c with
        | 'n' => numbering := numbering.enableAll
        | 'b' => numbering := .nonblank
        | 's' => squeeze := true
        | 'E' => showEnds := true
        | 'T' => showTabs := true
        | 'A' => do showEnds := true; showTabs := true
        | 'e' => showEnds := true
        | 't' => showTabs := true
        | 'u' => pure ()  -- accepted and ignored, as in GNU
        | 'v' => pure ()  -- non-printing display not implemented yet
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            return exitFail
    else
      filesRev := a :: filesRev
  let files := filesRev.reverse ++ positional
  let plain := numbering == .none && !squeeze && !showEnds && !showTabs
  let mut status := exitOk
  let mut lineNo := 1
  let mut prevBlank := false
  for file in operandsOrStdin files do
    try
      if plain then
        runByteStream file ByteChunkSize.fourMiB ByteStreamTransducer.identity
      else
        let (lines, endsNl) := linesOf (← readOperandText file)
        let mut out : List String := []
        let total := lines.length
        for (line, idx) in lines.zipIdx do
          let blank := line.isEmpty
          if squeeze && blank && prevBlank then
            continue
          prevBlank := blank
          let numbered := match numbering with
            | .none => false
            | .all => true
            | .nonblank => !blank
          let mut numPrefix := ""
          if numbered then
            numPrefix := s!"{padLeft 6 ' ' (toString lineNo)}\t"
            lineNo := lineNo + 1
          let isLast := idx + 1 == total
          let terminated := !isLast || endsNl
          let rendered := numPrefix ++ catDisplayLine showTabs (showEnds && terminated) line
          out := (if terminated then rendered ++ "\n" else rendered) :: out
        putStr ("".intercalate out.reverse)
    catch e =>
      if isBrokenPipe e then
        return exitOk
      reportFileError prog file e
      status := exitFail
  return status

end Lutils
