/- Tr utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- A parsed `tr` set. A `[c*]` repeat is recorded by position so it can be
expanded to whatever length pairing with the other set requires. -/
private structure TrSet where
  elems : List UInt8 := []
  fill : Option (Nat × UInt8) := none

private def TrSet.length (s : TrSet) : Nat := s.elems.length

/-- Expand a `[c*]` fill so the set has at least `target` elements. -/
private def TrSet.materialize (s : TrSet) (target : Nat) : List UInt8 :=
  match s.fill with
  | none => s.elems
  | some (pos, byte) =>
      if s.elems.length ≥ target then s.elems
      else
        let extra := List.replicate (target - s.elems.length) byte
        s.elems.take pos ++ extra ++ s.elems.drop pos

/-- The set as membership bytes (fills count once). -/
private def TrSet.members (s : TrSet) : List UInt8 :=
  match s.fill with
  | some (_, byte) => s.elems ++ [byte]
  | none => s.elems

private def classBytes : String → Option (List UInt8)
  | "alnum" => some byteRange
  | "alpha" => some (lower ++ upper)
  | "blank" => some [9, 32]
  | "cntrl" => some ((List.range 32).map UInt8.ofNat ++ [127])
  | "digit" => some digits
  | "graph" => some ((List.range 94).map (fun i => UInt8.ofNat (i + 33)))
  | "lower" => some lower
  | "print" => some ((List.range 95).map (fun i => UInt8.ofNat (i + 32)))
  | "punct" => some ((List.range 94).map (fun i => UInt8.ofNat (i + 33)) |>.filter
      (fun b => !byteRange.contains b))
  | "space" => some [9, 10, 11, 12, 13, 32]
  | "upper" => some upper
  | "xdigit" => some (digits ++ (List.range 6).map (fun i => UInt8.ofNat (i + 65)) ++
      (List.range 6).map (fun i => UInt8.ofNat (i + 97)))
  | _ => none
where
  digits := (List.range 10).map (fun i => UInt8.ofNat (i + 48))
  lower := (List.range 26).map (fun i => UInt8.ofNat (i + 97))
  upper := (List.range 26).map (fun i => UInt8.ofNat (i + 65))
  byteRange := digits ++ lower ++ upper

private def escapeByte (c : Char) : UInt8 :=
  UInt8.ofNat (match c with
    | 'a' => 7 | 'b' => 8 | 'f' => 12 | 'n' => 10
    | 'r' => 13 | 't' => 9 | 'v' => 11
    | other => other.toNat)

/-- Read one set element (a byte, a class, an equivalence, or a repeat).
Returns the produced bytes, an optional fill byte for `[c*]`, and the
remaining input. Simple bytes are marked so ranges can use them. -/
private inductive TrElem where
  | single (b : UInt8)
  | many (bs : List UInt8)
  | fill (b : UInt8)

private def startsWithStr (chars : List Char) (pat : String) : Bool :=
  (chars.take pat.length) == pat.toList

private def takeUntil (chars : List Char) (pat : String) : Option (List Char × List Char) :=
  go chars []
where
  go : List Char → List Char → Option (List Char × List Char)
    | [], _ => none
    | rest@(c :: more), acc =>
        if startsWithStr rest pat then some (acc.reverse, rest.drop pat.length)
        else go more (c :: acc)

private def parseElem (spec : String) : List Char → Except String (TrElem × List Char)
  | [] => .error s!"invalid set '{spec}'"
  | '\\' :: rest =>
      match rest with
      | [] => .ok (.single 92, [])
      | c :: more =>
          if '0' ≤ c && c ≤ '7' then
            let octals := (c :: more).takeWhile (fun d => '0' ≤ d && d ≤ '7') |>.take 3
            let value := octals.foldl (fun acc d => acc * 8 + (d.toNat - 48)) 0
            .ok (.single (UInt8.ofNat value), (c :: more).drop octals.length)
          else
            .ok (.single (escapeByte c), more)
  | '[' :: ':' :: rest =>
      match takeUntil rest ":]" with
      | none => .ok (.single 91, ':' :: rest)
      | some (nameChars, remaining) =>
          let name := String.ofList nameChars
          match classBytes name with
          | some bytes => .ok (.many bytes, remaining)
          | none => .error s!"invalid character class '{name}'"
  | '[' :: '=' :: c :: '=' :: ']' :: rest =>
      .ok (.single (UInt8.ofNat c.toNat), rest)
  | '[' :: c :: '*' :: rest =>
      let (countChars, remaining) := match takeUntil rest "]" with
        | some (inside, after) => (inside, after)
        | none => (rest, [])
      if countChars.isEmpty then
        .ok (.fill (UInt8.ofNat c.toNat), remaining)
      else
        let countStr := String.ofList countChars
        let parsed := if countStr.startsWith "0" && countStr.length > 1 then
          countStr.toList.foldl (fun acc d =>
            acc.bind fun a => if '0' ≤ d && d ≤ '7' then some (a * 8 + (d.toNat - 48)) else none) (some 0)
        else countStr.toNat?
        match parsed with
        | some n => .ok (.many (List.replicate n (UInt8.ofNat c.toNat)), remaining)
        | none => .error s!"invalid repeat count '{countStr}' in [c*n] construct"
  | c :: rest => .ok (.single (UInt8.ofNat c.toNat), rest)

/-- Parse a full `tr` set argument, expanding ranges and classes. -/
def parseTrSet (spec : String) : Except String TrSet := do
  let mut chars := spec.toList
  let mut out : List UInt8 := []
  let mut fill : Option (Nat × UInt8) := none
  while !chars.isEmpty do
    let (elem, rest) ← parseElem spec chars
    chars := rest
    match elem with
    | .single b =>
        match chars with
        | '-' :: afterDash =>
            if afterDash.isEmpty then
              out := out ++ [b]
            else
              let (elem2, rest2) ← parseElem spec afterDash
              match elem2 with
              | .single b2 =>
                  if b2.toNat < b.toNat then
                    throw s!"range-endpoints of '{spec}' are in reverse collating sequence order"
                  out := out ++ (List.range (b2.toNat - b.toNat + 1)).map
                    (fun i => UInt8.ofNat (b.toNat + i))
                  chars := rest2
              | _ => out := out ++ [b]
        | _ => out := out ++ [b]
    | .many bs => out := out ++ bs
    | .fill b => fill := some (out.length, b)
  return ⟨out, fill⟩

private def boolTable (bytes : List UInt8) : Array Bool := Id.run do
  let mut table := Array.replicate 256 false
  for b in bytes do
    table := table.set! b.toNat true
  return table

private def complementBytes (bytes : List UInt8) : List UInt8 :=
  let table := boolTable bytes
  (List.range 256).filterMap fun i =>
    if table.getD i false then none else some (UInt8.ofNat i)

/-- `tr [OPTION]... SET1 [SET2]`: translate, delete, and squeeze bytes from
standard input, streamed through a pure byte transducer. -/
def runTr : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "tr [OPTION]... SET1 [SET2]" args then
    return code
  let mut complement := false
  let mut delete := false
  let mut squeeze := false
  let mut truncate := false
  let mut operands : List String := []
  let tryMsg := s!"Try '{prog} --help' for more information."
  let (before, positional) := splitDoubleDash args
  for arg in before do
    if arg == "-" || !arg.startsWith "-" then
      operands := operands ++ [arg]
    else if arg.startsWith "--" then
      match arg with
      | "--complement" => complement := true
      | "--delete" => delete := true
      | "--squeeze-repeats" => squeeze := true
      | "--truncate-set1" => truncate := true
      | _ =>
          reportError prog s!"unrecognized option '{arg}'"
          IO.eprintln tryMsg
          return exitFail
    else
      for c in (arg.drop 1).toString.toList do
        match c with
        | 'c' | 'C' => complement := true
        | 'd' => delete := true
        | 's' => squeeze := true
        | 't' => truncate := true
        | _ =>
            reportError prog s!"invalid option -- '{c}'"
            IO.eprintln tryMsg
            return exitFail
  operands := operands ++ positional
  let missingAfter (what : String) (sentence : String) : IO UInt32 := do
    reportError prog s!"missing operand after '{what}'"
    IO.eprintln sentence
    IO.eprintln tryMsg
    return exitFail
  match operands with
  | [] =>
      reportError prog "missing operand"
      IO.eprintln tryMsg
      return exitFail
  | [only] =>
      if delete && squeeze then
        return ← missingAfter only
          "Two strings must be given when both deleting and squeezing repeats."
      if !delete && !squeeze then
        return ← missingAfter only "Two strings must be given when translating."
  | [_, second] =>
      if delete && !squeeze then
        reportError prog s!"extra operand '{second}'"
        IO.eprintln "Only one string may be given when deleting without squeezing repeats."
        IO.eprintln tryMsg
        return exitFail
  | _ :: _ :: third :: _ =>
      reportError prog s!"extra operand '{third}'"
      IO.eprintln tryMsg
      return exitFail
  let parseOrFail (spec : String) : IO (Option TrSet) := do
    let trailing := spec.toList.reverse.takeWhile (· == '\\') |>.length
    if trailing % 2 == 1 then
      IO.eprintln s!"{prog}: warning: an unescaped backslash at end of string is not portable"
    match parseTrSet spec with
    | .ok set => return some set
    | .error msg =>
        reportError prog msg
        return none
  let some set1 ← parseOrFail (operands.head?.getD "") | return exitFail
  let mut set2 : Option TrSet := none
  match operands with
  | [_, second] =>
      let some parsed ← parseOrFail second | return exitFail
      set2 := some parsed
  | _ => pure ()
  -- Build the translation table, deletion set, and squeeze set.
  let mut table : Option (Array UInt8) := none
  let mut deleteBytes : List UInt8 := []
  let mut squeezeBytes : Option (List UInt8) := none
  match set2 with
  | some s2 =>
      if delete then
        deleteBytes := if complement then complementBytes set1.members else set1.members
        squeezeBytes := some s2.members
      else
        let s1list := (if complement then complementBytes set1.members
          else set1.materialize s2.elems.length)
        let s2list := s2.materialize s1list.length
        if s2list.isEmpty && !truncate then
          reportError prog "when not truncating set1, string2 must be non-empty"
          return exitFail
        let s1list := if truncate then s1list.take s2list.length else s1list
        let mut map := (Array.range 256).map UInt8.ofNat
        for (fromB, i) in s1list.zipIdx do
          match s2list[i]? with
          | some toB => map := map.set! fromB.toNat toB
          | none =>
              match s2list.getLast? with
              | some toB => map := map.set! fromB.toNat toB
              | none => pure ()
        table := some map
        if squeeze then squeezeBytes := some s2.members
  | none =>
      let members := if complement then complementBytes set1.members else set1.members
      if delete then deleteBytes := members
      if squeeze then squeezeBytes := some members
  let deleteTable := boolTable deleteBytes
  let squeezeTable := squeezeBytes.map boolTable
  let transducer : ByteStreamTransducer (Option UInt8) Unit :=
    { initial := none
      step := fun last input => Id.run do
        let mut state := last
        let mut out := ByteArray.empty
        for byte in input do
          if deleteTable.getD byte.toNat false then
            continue
          let mapped := match table with
            | some m => m.getD byte.toNat byte
            | none => byte
          let squeezed := match squeezeTable with
            | some t => t.getD mapped.toNat false && state == some mapped
            | none => false
          if !squeezed then
            out := out.push mapped
            state := some mapped
        return (state, out)
      finish := fun _ => (ByteArray.empty, ()) }
  try
    runByteStream "-" ByteChunkSize.fourMiB transducer
    return exitOk
  catch e =>
    if isBrokenPipe e then return exitOk
    reportError prog (describeError e)
    return exitFail

end Lutils
