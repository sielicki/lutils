/- A small pure byte-oriented regular-expression matcher. -/
import Lutils.Shared.Common

namespace Lutils

inductive GrepAtom where
  | literal (byte : UInt8)
  | any
  | bracket (bytes : List UInt8) (inverted : Bool)
  | begin
  | finish

inductive GrepRepeat where
  | once | optional | many | some

structure GrepPiece where
  atom : GrepAtom
  repetition : GrepRepeat := .once

structure GrepRegex where
  startAnchor : Bool := false
  endAnchor : Bool := false
  pieces : List GrepPiece := []

def GrepAtom.accepts (atom : GrepAtom) (byte : UInt8) : Bool :=
  match atom with
  | .literal expected => byte == expected
  | .any => true
  | .bracket bytes inverted => bytes.contains byte != inverted
  | .begin | .finish => false

theorem GrepAtom.literal_accepts_self (byte : UInt8) :
    (GrepAtom.literal byte).accepts byte = true := by
  simp [GrepAtom.accepts]

private def grepRange (first last : UInt8) : List UInt8 :=
  if first.toNat ≤ last.toNat then
    (List.range (last.toNat - first.toNat + 1)).map fun n => UInt8.ofNat (first.toNat + n)
  else []

private def grepClassBytes : List UInt8 → List UInt8
  | a :: dash :: b :: rest =>
    if dash == 45 then grepRange a b ++ grepClassBytes rest
    else a :: grepClassBytes (dash :: b :: rest)
  | bytes => bytes

private def grepBracket (bytes : List UInt8) : Except String (GrepAtom × List UInt8) :=
  let (inverted, bytes) := match bytes with
    | 94 :: rest => (true, rest)
    | rest => (false, rest)
  let (body, tail) := bytes.span (· != 93)
  match tail with
  | [] => .error "Unmatched ["
  | _ :: rest => .ok (.bracket (grepClassBytes body) inverted, rest)

/-- Parse the supported single-branch BRE/ERE operators into a typed program. -/
partial def grepCompileRegex (extended : Bool) (pattern : ByteArray) : Except String GrepRegex := do
  let bytes := pattern.toList
  let (startAnchor, bytes) := match bytes with
    | 94 :: rest => (true, rest)
    | rest => (false, rest)
  let (endAnchor, bytes) :=
    if bytes.getLast? == some 36 then (true, bytes.dropLast) else (false, bytes)
  let pieces ← go [] bytes
  return { startAnchor := startAnchor, endAnchor := endAnchor, pieces := pieces.reverse }
where
  go (reversed : List GrepPiece) : List UInt8 → Except String (List GrepPiece)
    | [] => .ok reversed
    | 92 :: escaped :: rest =>
      if !extended && (escaped == 43 || escaped == 63) then
        setRepeat reversed (if escaped == 43 then .some else .optional) rest
      else if (!extended && (escaped == 40 || escaped == 41 || escaped == 124 ||
          escaped == 123 || (49 ≤ escaped.toNat && escaped.toNat ≤ 57))) ||
          (extended && 49 ≤ escaped.toNat && escaped.toNat ≤ 57) then
        .error "unsupported regular expression construct"
      else go (⟨.literal escaped, .once⟩ :: reversed) rest
    | [92] => go (⟨.literal 92, .once⟩ :: reversed) []
    | 91 :: rest => do
      let (atom, tail) ← grepBracket rest
      go (⟨atom, .once⟩ :: reversed) tail
    | 46 :: rest => go (⟨.any, .once⟩ :: reversed) rest
    | 42 :: rest => setRepeat reversed .many rest
    | 43 :: rest =>
      if extended then setRepeat reversed .some rest
      else go (⟨.literal 43, .once⟩ :: reversed) rest
    | 63 :: rest =>
      if extended then setRepeat reversed .optional rest
      else go (⟨.literal 63, .once⟩ :: reversed) rest
    | byte :: rest =>
      if extended && (byte == 40 || byte == 41 || byte == 124 || byte == 123) then
        .error "unsupported regular expression construct"
      else if extended && byte == 94 then
        go (⟨.begin, .once⟩ :: reversed) rest
      else if extended && byte == 36 then
        go (⟨.finish, .once⟩ :: reversed) rest
      else go (⟨.literal byte, .once⟩ :: reversed) rest
  setRepeat (reversed : List GrepPiece) (repetition : GrepRepeat) (rest : List UInt8) :
      Except String (List GrepPiece) :=
    match reversed with
    | [] => go (⟨.literal 42, .once⟩ :: reversed) rest
    | piece :: tail => go ({ piece with repetition := repetition } :: tail) rest

/-- Every position reachable by repeatedly consuming one atom. -/
def grepReachable (atom : GrepAtom) (line : ByteArray) (start : Nat) : List Nat := Id.run do
  let mut positions := [start]
  let mut active := true
  for h : i in [start:line.size] do
    if active then
      if atom.accepts line[i] then positions := (i + 1) :: positions
      else active := false
  return positions

/-- The matcher recurses structurally on the pattern, never on input size. -/
def grepMatchPieces (pieces : List GrepPiece) (line : ByteArray) (offset : Nat)
    (endAnchor : Bool) : Bool :=
  match pieces with
  | [] => !endAnchor || offset == line.size
  | piece :: tail =>
    match piece.atom with
    | .begin => offset == 0 && grepMatchPieces tail line offset endAnchor
    | .finish => offset == line.size && grepMatchPieces tail line offset endAnchor
    | atom =>
      let positions := grepReachable atom line offset
      let candidates := match piece.repetition with
        | .once => if positions.length > 1 then [offset + 1] else []
        | .optional => if positions.length > 1 then [offset, offset + 1] else [offset]
        | .many => positions
        | .some => positions.filter (· > offset)
      candidates.any fun next => grepMatchPieces tail line next endAnchor

def GrepRegex.matches (regex : GrepRegex) (line : ByteArray) : Bool :=
  if regex.startAnchor then grepMatchPieces regex.pieces line 0 regex.endAnchor
  else (List.range (line.size + 1)).any fun start =>
    grepMatchPieces regex.pieces line start regex.endAnchor

/-- Search with a predicate on match bounds, used for word boundaries. -/
def GrepRegex.matchesBounds (regex : GrepRegex) (line : ByteArray)
    (eligible : Nat → Nat → Bool) : Bool := Id.run do
  for start in [:line.size + 1] do
    if !regex.startAnchor || start == 0 then
      for stop in [start:line.size + 1] do
        if (!regex.endAnchor || stop == line.size) && eligible start stop &&
            grepMatchPieces regex.pieces (line.extract 0 stop) start true then
          return true
  return false

/-- Leftmost, longest positive-length match at or after `from`. -/
def GrepRegex.findPositive (regex : GrepRegex) (line : ByteArray)
    (fromOffset : Nat) : Option (Nat × Nat) := Id.run do
  for start in [fromOffset:line.size] do
    if !regex.startAnchor || start == 0 then
      for length in [:line.size - start] do
        let stop := line.size - length
        if start < stop && (!regex.endAnchor || stop == line.size) &&
            grepMatchPieces regex.pieces (line.extract 0 stop) start true then
          return some (start, stop)
  return none

theorem grepMatchPieces_empty (line : ByteArray) (offset : Nat) :
    grepMatchPieces [] line offset false = true := by
  simp [grepMatchPieces]

end Lutils
