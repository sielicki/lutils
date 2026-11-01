/- Echo utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- Text produced by escape expansion and whether `\c` stopped output. -/
structure EchoExpansion where
  text : String
  stopped : Bool

/-- Expand `echo -e` backslash escapes. Returns the expanded text plus
whether a `\c` escape asks to suppress all further output. -/
def expandEchoEscapes (input : List Char) : EchoExpansion :=
  go input []
where
  go : List Char → List Char → EchoExpansion
    | [], acc => ⟨String.ofList acc.reverse, false⟩
    | '\\' :: rest, acc =>
        match rest with
        | [] => ⟨String.ofList ('\\' :: acc).reverse, false⟩
        | 'a' :: t => go t ('\x07' :: acc)
        | 'b' :: t => go t ('\x08' :: acc)
        | 'c' :: _ => ⟨String.ofList acc.reverse, true⟩
        | 'e' :: t => go t ('\x1b' :: acc)
        | 'f' :: t => go t ('\x0c' :: acc)
        | 'n' :: t => go t ('\n' :: acc)
        | 'r' :: t => go t ('\r' :: acc)
        | 't' :: t => go t ('\t' :: acc)
        | 'v' :: t => go t ('\x0b' :: acc)
        | '\\' :: t => go t ('\\' :: acc)
        | '0' :: t =>
            let ds := t.takeWhile (fun c => '0' <= c && c <= '7') |>.take 3
            let n := ds.foldl (fun a c => a * 8 + (c.toNat - '0'.toNat)) 0
            go (t.drop ds.length) (Char.ofNat (n % 256) :: acc)
        | 'x' :: t =>
            let ds := t.takeWhile (·.isHexDigit) |>.take 2
            if ds.isEmpty then
              go t ('x' :: '\\' :: acc)
            else
              let hexVal (c : Char) : Nat :=
                if '0' <= c && c <= '9' then c.toNat - '0'.toNat
                else if 'a' <= c && c <= 'f' then c.toNat - 'a'.toNat + 10
                else c.toNat - 'A'.toNat + 10
              let n := ds.foldl (fun a c => a * 16 + hexVal c) 0
              go (t.drop ds.length) (Char.ofNat n :: acc)
        | c :: t => go t (c :: '\\' :: acc)
    | c :: rest, acc => go rest (c :: acc)
  termination_by xs _ => xs.length

private theorem echoGoNoSlash (xs acc : List Char) (h : '\\' ∉ xs) :
    expandEchoEscapes.go xs acc = ⟨String.ofList (acc.reverse ++ xs), false⟩ := by
  induction xs generalizing acc with
  | nil => simp [expandEchoEscapes.go]
  | cons c cs ih =>
      have hc : c ≠ '\\' := by
        intro heq
        simp [heq] at h
      have ht : '\\' ∉ cs := by
        intro hm
        exact h (List.mem_cons_of_mem c hm)
      simp [expandEchoEscapes.go, ih, ht, List.reverse_cons,
            List.append_assoc]

/-- Escape expansion leaves text without backslashes unchanged. -/
theorem expandEchoEscapes_noBackslash (s : String)
    (h : s.contains '\\' = false) :
    expandEchoEscapes s.toList = ⟨s, false⟩ := by
  have hm : '\\' ∉ s.toList := by
    simpa [String.contains_char_eq] using h
  simpa [expandEchoEscapes, String.ofList_toList] using
    echoGoNoSlash s.toList [] hm

/-- Skip list conversion for the common `-e` input with no backslash. -/
def expandEchoEscapesFast (s : String) : EchoExpansion :=
  if s.contains '\\' then expandEchoEscapes s.toList else ⟨s, false⟩

/-- The fast path preserves the original expansion behavior. -/
theorem expandEchoEscapesFast_eq (s : String) :
    expandEchoEscapesFast s = expandEchoEscapes s.toList := by
  by_cases h : s.contains '\\' = true
  · simp [expandEchoEscapesFast, h]
  · have hf : s.contains '\\' = false := Bool.eq_false_of_ne_true h
    simp [expandEchoEscapesFast, hf, expandEchoEscapes_noBackslash s hf]

/-- `echo [-n] [-e|-E] [STRING]...` -/
def runEcho : Applet := fun prog args => do
  -- GNU echo only treats an exact sole `--help`/`--version` specially.
  match args with
  | ["--help"] => return ← helpAndExit prog "echo [OPTION]... [STRING]..."
  | ["--version"] => return ← versionAndExit prog
  | _ => pure ()
  let mut newline := true
  let mut escapes := false
  let mut rest := args
  let mut scanning := true
  while scanning do
    match rest with
    | a :: t =>
        let cs := a.toList
        if a == "--" then
          rest := t
          scanning := false
        else if cs.length > 1 && cs.head? == some '-' &&
            (cs.drop 1).all (fun c => c == 'n' || c == 'e' || c == 'E') then
          for c in cs.drop 1 do
            match c with
            | 'n' => newline := false
            | 'e' => escapes := true
            | 'E' => escapes := false
            | _ => pure ()
          rest := t
        else
          scanning := false
    | [] => scanning := false
  let joined := " ".intercalate rest
  let expansion :=
    if escapes then expandEchoEscapesFast joined else ⟨joined, false⟩
  try
    putStr expansion.text
    if newline && !expansion.stopped then putStr "\n"
    return exitOk
  catch e =>
    return if isBrokenPipe e then exitOk else exitFail

end Lutils
