import Lutils.Shared.Common
import Std.Tactic.BVDecide

namespace Lutils.BaseEncoding

/-- The power-of-two alphabets exposed by `basenc`. -/
inductive Codec where
  | base64 | base64url | base32 | base32hex | base16 | base2msbf | base2lsbf
  deriving BEq, DecidableEq

/-- Bits represented by one output digit. -/
def Codec.width : Codec → Nat
  | .base64 | .base64url => 6
  | .base32 | .base32hex => 5
  | .base16 => 4
  | .base2msbf | .base2lsbf => 1

/-- The padded output quantum in digits; one means no padding. -/
def Codec.quantum : Codec → Nat
  | .base64 | .base64url => 4
  | .base32 | .base32hex => 8
  | .base16 | .base2msbf | .base2lsbf => 1

/-- Input bytes in one complete encoding block. -/
def Codec.inputQuantum : Codec → Nat
  | .base64 | .base64url => 3
  | .base32 | .base32hex => 5
  | .base16 | .base2msbf | .base2lsbf => 1

theorem Codec.inputQuantum_pos (codec : Codec) : 0 < codec.inputQuantum := by
  cases codec <;> decide

theorem Codec.width_pos (codec : Codec) : 0 < codec.width := by
  cases codec <;> decide

theorem Codec.quantum_pos (codec : Codec) : 0 < codec.quantum := by
  cases codec <;> decide

/-- A fixed-size alphabet; malformed alphabet lengths cannot be constructed. -/
structure Alphabet (width : Nat) where
  symbols : Vector UInt8 (2 ^ width)

private def alphabet (codec : Codec) : Alphabet codec.width :=
  match codec with
  | .base64 => ⟨Vector.mk "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toUTF8.data (by decide)⟩
  | .base64url => ⟨Vector.mk "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".toUTF8.data (by decide)⟩
  | .base32 => ⟨Vector.mk "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".toUTF8.data (by decide)⟩
  | .base32hex => ⟨Vector.mk "0123456789ABCDEFGHIJKLMNOPQRSTUV".toUTF8.data (by decide)⟩
  | .base16 => ⟨Vector.mk "0123456789ABCDEF".toUTF8.data (by decide)⟩
  | .base2msbf | .base2lsbf => ⟨Vector.mk "01".toUTF8.data (by decide)⟩

@[inline] private def putDigit (alphabet : Alphabet width) (value : Nat) (h : value < 2 ^ width)
    (out : ByteArray) : ByteArray :=
  out.push (alphabet.symbols[value]'h)

/-- The base-2 variants differ only in the order of each byte's bits. -/
private def reverseBits (byte : UInt8) : UInt8 := Id.run do
  let mut out : UInt8 := 0
  for i in [0:8] do
    out := (out <<< 1) ||| ((byte >>> UInt8.ofNat i) &&& 1)
  return out

/-- Encode an arbitrary byte sequence without line wrapping. -/
private def encodeBits (codec : Codec) (input : ByteArray) : ByteArray := Id.run do
  let width := codec.width
  let radix := 2 ^ width
  let symbols := alphabet codec
  let mut out := ByteArray.empty
  let mut bits := 0
  let mut carry : UInt32 := 0
  for byte in input do
    let byte := if codec == .base2lsbf then reverseBits byte else byte
    carry := (carry <<< 8) ||| byte.toUInt32
    bits := bits + 8
    while bits >= width do
      bits := bits - width
      let digit := ((carry >>> UInt32.ofNat bits) &&& UInt32.ofNat (radix - 1)).toNat % radix
      out := putDigit symbols digit (Nat.mod_lt _ (by cases codec <;> decide)) out
    carry := carry &&& UInt32.ofNat (2 ^ bits - 1)
  if bits > 0 then
    let digit := ((carry <<< UInt32.ofNat (width - bits)) &&& UInt32.ofNat (radix - 1)).toNat % radix
    out := putDigit symbols digit (Nat.mod_lt _ (by cases codec <;> decide)) out
  while out.size % codec.quantum != 0 do
    out := out.push 61
  return out

/-- Encode complete three-byte blocks directly into Base64 digits. -/
@[inline] private def pack64 (a b c : UInt8) : UInt32 :=
  (a.toUInt32 <<< 16) ||| (b.toUInt32 <<< 8) ||| c.toUInt32

/-- Packing a complete Base64 input block preserves all three bytes. -/
theorem pack64_roundtrip (a b c : UInt8) :
    ((pack64 a b c >>> 16).toUInt8,
      (pack64 a b c >>> 8).toUInt8,
      (pack64 a b c).toUInt8) = (a, b, c) := by
  simp only [Prod.mk.injEq]
  constructor
  · unfold pack64; bv_decide
  · constructor <;> (unfold pack64; bv_decide)

private def encode64 (symbols : Alphabet 6) (input : ByteArray) : ByteArray := Id.run do
  let blocks := (input.size + 2) / 3
  let mut out := ByteArray.emptyWithCapacity (blocks * 4)
  let mut index := 0
  while h : index < input.size / 3 do
    let i := index * 3
    have hi : i + 2 < input.size := by
      have hdiv := Nat.div_mul_le_self input.size 3
      omega
    let a := input[i]'(by omega)
    let b := input[i + 1]'(by omega)
    let c := input[i + 2]'hi
    let word := pack64 a b c
    out := putDigit symbols ((word >>> 18).toNat % 64) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 12).toNat % 64) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 6).toNat % 64) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols (word.toNat % 64) (Nat.mod_lt _ (by decide)) out
    index := index + 1
  let tail := input.size % 3
  if htail : tail > 0 then
    let i := input.size / 3 * 3
    have hsplit : tail + i = input.size := by
      simpa [tail, i, Nat.mul_comm] using Nat.mod_add_div input.size 3
    let a := input[i]'(by omega)
    let b := if h : tail = 2 then input[i + 1]'(by omega) else 0
    let word := pack64 a b 0
    out := putDigit symbols ((word >>> 18).toNat % 64) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 12).toNat % 64) (Nat.mod_lt _ (by decide)) out
    if tail == 2 then
      out := putDigit symbols ((word >>> 6).toNat % 64) (Nat.mod_lt _ (by decide)) out
    else out := out.push 61
    out := out.push 61
  return out

/-- Encode five-byte blocks into Base32 digits. -/
@[inline] private def pack32 (a b c d e : UInt8) : UInt64 :=
  (a.toUInt64 <<< 32) ||| (b.toUInt64 <<< 24) |||
    (c.toUInt64 <<< 16) ||| (d.toUInt64 <<< 8) ||| e.toUInt64

/-- Packing a complete Base32 input block preserves all five bytes. -/
theorem pack32_roundtrip (a b c d e : UInt8) :
    ((pack32 a b c d e >>> 32).toUInt8,
      (pack32 a b c d e >>> 24).toUInt8,
      (pack32 a b c d e >>> 16).toUInt8,
      (pack32 a b c d e >>> 8).toUInt8,
      (pack32 a b c d e).toUInt8) = (a, b, c, d, e) := by
  simp only [Prod.mk.injEq]
  constructor
  · unfold pack32; bv_decide
  · constructor
    · unfold pack32; bv_decide
    · constructor
      · unfold pack32; bv_decide
      · constructor <;> (unfold pack32; bv_decide)

private def encode32 (symbols : Alphabet 5) (input : ByteArray) : ByteArray := Id.run do
  let blocks := (input.size + 4) / 5
  let mut out := ByteArray.emptyWithCapacity (blocks * 8)
  let mut index := 0
  while h : index < input.size / 5 do
    let i := index * 5
    have hi : i + 4 < input.size := by
      have hdiv := Nat.div_mul_le_self input.size 5
      omega
    let a := input[i]'(by omega)
    let b := input[i + 1]'(by omega)
    let c := input[i + 2]'(by omega)
    let d := input[i + 3]'(by omega)
    let e := input[i + 4]'hi
    let word := pack32 a b c d e
    out := putDigit symbols ((word >>> 35).toNat % 32) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 30).toNat % 32) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 25).toNat % 32) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 20).toNat % 32) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 15).toNat % 32) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 10).toNat % 32) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols ((word >>> 5).toNat % 32) (Nat.mod_lt _ (by decide)) out
    out := putDigit symbols (word.toNat % 32) (Nat.mod_lt _ (by decide)) out
    index := index + 1
  let tail := input.size % 5
  if htail : tail > 0 then
    let i := input.size / 5 * 5
    have hsplit : tail + i = input.size := by
      simpa [tail, i, Nat.mul_comm] using Nat.mod_add_div input.size 5
    let a := input[i]'(by omega)
    let b := if h : tail ≥ 2 then input[i + 1]'(by omega) else 0
    let c := if h : tail ≥ 3 then input[i + 2]'(by omega) else 0
    let d := if h : tail ≥ 4 then input[i + 3]'(by omega) else 0
    let word := pack32 a b c d 0
    let digits := if tail == 1 then 2 else if tail == 2 then 4 else
      if tail == 3 then 5 else 7
    for k in [0:8] do
      if k < digits then
        let digit := ((word >>> UInt64.ofNat (35 - 5 * k)).toNat) % 32
        out := putDigit symbols digit (Nat.mod_lt _ (by decide)) out
      else out := out.push 61
  return out

/-- Encode an arbitrary byte sequence without line wrapping. -/
def encode (codec : Codec) (input : ByteArray) : ByteArray :=
  match codec with
  | .base64 => encode64 (alphabet .base64) input
  | .base64url => encode64 (alphabet .base64url) input
  | .base32 => encode32 (alphabet .base32) input
  | .base32hex => encode32 (alphabet .base32hex) input
  | _ => encodeBits codec input

/-- Decoding outcomes retain bytes already emitted before an invalid suffix. -/
structure DecodeResult where
  bytes : ByteArray
  valid : Bool

/-- A fixed-size byte lookup table for decoding one alphabet. -/
private abbrev DigitTable := Vector (Option Nat) 256

private def digitTable (codec : Codec) : DigitTable := Id.run do
  let symbols := (alphabet codec).symbols
  let mut table : DigitTable := Vector.replicate 256 none
  for index in List.finRange (2 ^ codec.width) do
    let byte := symbols[index.val]
    table := table.set byte.toNat (some index.val)
      (by have h := UInt8.toNat_lt byte; omega)
    if h : codec = .base16 ∧ 65 ≤ byte.toNat ∧ byte.toNat ≤ 70 then
      table := table.set (byte.toNat + 32) (some index.val)
        (by omega)
  return table

-- Every alphabet digit is below 64, leaving 255 as an invalid marker.
@[inline] private def readDigit (table : DigitTable) (input : ByteArray)
    (i : Nat) (h : i < input.size) : UInt8 :=
  let byte := input[i]'h
  match table[byte.toNat]'(by have h := UInt8.toNat_lt byte; omega) with
  | some digit => UInt8.ofNat digit
  | none => 255

private def expectedPadding (codec : Codec) (digits : Nat) : Nat :=
  match codec with
  | .base64 | .base64url => if digits == 2 then 2 else if digits == 3 then 1 else 0
  | .base32 | .base32hex =>
    if digits == 2 then 6 else if digits == 4 then 4 else
    if digits == 5 then 3 else if digits == 7 then 1 else 0
  | _ => 0

private def isNewline (byte : UInt8) : Bool := byte == 10

private def validRemainder (codec : Codec) (digits : Nat) : Bool :=
  match codec with
  | .base64 | .base64url => digits == 0 || digits == 2 || digits == 3
  | .base32 | .base32hex =>
    digits == 0 || digits == 2 || digits == 4 || digits == 5 || digits == 7
  | .base16 => digits == 0
  | .base2msbf | .base2lsbf => true

/-- Decode a power-of-two alphabet. Newlines are ignored; other garbage is optional. -/
private def decodeBits (codec : Codec) (ignoreGarbage : Bool) (input : ByteArray) : DecodeResult := Id.run do
  let width := codec.width
  let radix := 2 ^ width
  let lookup := digitTable codec
  let mut out := ByteArray.empty
  let mut carry := 0
  let mut bits := 0
  let mut seenPadding := false
  let mut paddingCount := 0
  let mut digitsInGroup := 0
  let mut groupStart := 0
  let mut valid := true
  for byte in input do
    if isNewline byte then continue
    if byte == 61 && codec.quantum > 1 then
      seenPadding := true
      paddingCount := paddingCount + 1
      continue
    match lookup[byte.toNat]'(by have h := UInt8.toNat_lt byte; omega) with
    | some digit =>
      if seenPadding then
        if paddingCount != expectedPadding codec digitsInGroup then
          if codec == .base32 || codec == .base32hex then
            out := out.extract 0 groupStart
          valid := false
          break
        seenPadding := false
        paddingCount := 0
        digitsInGroup := 0
      if digitsInGroup == 0 then groupStart := out.size
      carry := carry * radix + digit
      bits := bits + width
      digitsInGroup := (digitsInGroup + 1) % codec.quantum
      if bits >= 8 then
        bits := bits - 8
        out := out.push (UInt8.ofNat (carry / 2 ^ bits))
        carry := carry % 2 ^ bits
    | none =>
      if !ignoreGarbage then
        valid := false
        break
  if bits > 0 && carry != 0 then valid := false
  if !validRemainder codec digitsInGroup then valid := false
  if codec == .base16 && bits != 0 then valid := false
  if seenPadding && paddingCount != expectedPadding codec digitsInGroup then
    if codec == .base32 || codec == .base32hex then
      out := out.extract 0 groupStart
    valid := false
  if codec == .base2lsbf then
    out := ByteArray.mk (out.data.map reverseBits)
  return ⟨out, valid⟩

/-- Decode a newline-free, correctly padded Base64 stream four digits at a time. -/
private def decode64Fast (codec : Codec) (input : ByteArray) : Option ByteArray := Id.run do
  if input.size % 4 != 0 then return none
  let lookup := digitTable codec
  let mut out := ByteArray.emptyWithCapacity (input.size / 4 * 3)
  let mut i := 0
  while i < input.size do
    if h : i + 3 < input.size then
      let c := input[i + 2]'(by omega)
      let d := input[i + 3]'h
      let x8 := readDigit lookup input i (by omega)
      let y8 := readDigit lookup input (i + 1) (by omega)
      if x8 == 255 || y8 == 255 then return none
      let x := x8.toUInt64
      let y := y8.toUInt64
      if c == 61 then
        if d != 61 || i + 4 != input.size || y % 16 != 0 then return none
        out := out.push (x * 4 + y / 16).toUInt8
        return some out
      let z8 := readDigit lookup input (i + 2) (by omega)
      if z8 == 255 then return none
      let z := z8.toUInt64
      if d == 61 then
        if i + 4 != input.size || z % 4 != 0 then return none
        out := out.push (x * 4 + y / 16).toUInt8
        out := out.push (y * 16 + z / 4).toUInt8
        return some out
      let w8 := readDigit lookup input (i + 3) (by omega)
      if w8 == 255 then return none
      let w := w8.toUInt64
      let word := (x <<< 18) ||| (y <<< 12) ||| (z <<< 6) ||| w
      out := out.push (word >>> 16).toUInt8
      out := out.push (word >>> 8).toUInt8
      out := out.push word.toUInt8
      i := i + 4
    else return none
  return some out

/-- Decode full Base32 quanta with fixed-width arithmetic. -/
private def decode32Fast (codec : Codec) (input : ByteArray) : Option ByteArray := Id.run do
  if input.size % 8 != 0 then return none
  let lookup := digitTable codec
  let mut out := ByteArray.emptyWithCapacity (input.size / 8 * 5)
  let mut i := 0
  while i < input.size do
    if h : i + 8 ≤ input.size then
      if input[i + 7]'(by omega) == 61 then
        if i + 8 != input.size then return none
        let tail := decodeBits codec false (input.extract i input.size)
        if !tail.valid then return none
        return some (out ++ tail.bytes)
      let a := readDigit lookup input i (by omega)
      let b := readDigit lookup input (i + 1) (by omega)
      let c := readDigit lookup input (i + 2) (by omega)
      let d := readDigit lookup input (i + 3) (by omega)
      let e := readDigit lookup input (i + 4) (by omega)
      let f := readDigit lookup input (i + 5) (by omega)
      let g := readDigit lookup input (i + 6) (by omega)
      let z := readDigit lookup input (i + 7) (by omega)
      if a == 255 || b == 255 || c == 255 || d == 255 ||
          e == 255 || f == 255 || g == 255 || z == 255 then return none
      let word := (a.toUInt64 <<< 35) ||| (b.toUInt64 <<< 30) |||
        (c.toUInt64 <<< 25) ||| (d.toUInt64 <<< 20) |||
        (e.toUInt64 <<< 15) ||| (f.toUInt64 <<< 10) |||
        (g.toUInt64 <<< 5) ||| z.toUInt64
      out := out.push (word >>> 32).toUInt8
      out := out.push (word >>> 24).toUInt8
      out := out.push (word >>> 16).toUInt8
      out := out.push (word >>> 8).toUInt8
      out := out.push word.toUInt8
      i := i + 8
    else return none
  return some out

/-- Decode with a block path for common valid streams and a general recovery path. -/
def decode (codec : Codec) (ignoreGarbage : Bool) (input : ByteArray) : DecodeResult :=
  let fast := match codec with
    | .base64 | .base64url => decode64Fast codec input
    | .base32 | .base32hex => decode32Fast codec input
    | _ => none
  match fast with
  | some bytes => ⟨bytes, true⟩
  | none => decodeBits codec ignoreGarbage input

/-- Decoder state for inputs that contain newlines, padding, or malformed data.
The last digit group stays staged until its padding can be checked. -/
structure BitsDecodeState where
  table : DigitTable
  carry : Nat := 0
  bits : Nat := 0
  seenPadding : Bool := false
  paddingCount : Nat := 0
  digitsInGroup : Nat := 0
  staged : ByteArray := ByteArray.empty
  valid : Bool := true
  halted : Bool := false
  dropStaged : Bool := false

private def BitsDecodeState.initial (codec : Codec) : BitsDecodeState :=
  { table := digitTable codec }

/-- The general decoder transition is pure and retains only one output group. -/
private def decodeBitsStreamChunk (codec : Codec) (ignoreGarbage : Bool)
    (initial : BitsDecodeState) (input : ByteArray) : BitsDecodeState × ByteArray := Id.run do
  let mut state := initial
  let mut emitted := ByteArray.empty
  let width := codec.width
  let radix := 2 ^ width
  for byte in input do
    if state.halted then break
    if isNewline byte then continue
    if byte == 61 && codec.quantum > 1 then
      state := { state with seenPadding := true, paddingCount := state.paddingCount + 1 }
      continue
    match state.table[byte.toNat]'(by have h := UInt8.toNat_lt byte; omega) with
    | some digit =>
      if state.seenPadding then
        if state.paddingCount != expectedPadding codec state.digitsInGroup then
          let dropGroup := codec == .base32 || codec == .base32hex
          state := { state with valid := false, halted := true, dropStaged := dropGroup }
          break
        state := { state with seenPadding := false, paddingCount := 0, digitsInGroup := 0 }
      if state.digitsInGroup == 0 then
        emitted := emitted ++ state.staged
        state := { state with staged := ByteArray.empty }
      let carry := state.carry * radix + digit
      let bits := state.bits + width
      let digitsInGroup := (state.digitsInGroup + 1) % codec.quantum
      if bits >= 8 then
        let remaining := bits - 8
        state := { state with carry := carry % 2 ^ remaining, bits := remaining, digitsInGroup := digitsInGroup, staged := state.staged.push (UInt8.ofNat (carry / 2 ^ remaining)) }
      else
        state := { state with carry := carry, bits := bits, digitsInGroup := digitsInGroup }
    | none =>
      if !ignoreGarbage then
        state := { state with valid := false, halted := true }
  let output := if codec == .base2lsbf then
    ByteArray.mk (emitted.data.map reverseBits) else emitted
  return (state, output)

private def finishBitsDecode (codec : Codec) (state : BitsDecodeState) : DecodeResult :=
  let paddingBad := state.seenPadding &&
    state.paddingCount != expectedPadding codec state.digitsInGroup
  let dropGroup := state.dropStaged ||
    (paddingBad && (codec == .base32 || codec == .base32hex))
  let bytes := if dropGroup then ByteArray.empty else state.staged
  let bytes := if codec == .base2lsbf then
    ByteArray.mk (bytes.data.map reverseBits) else bytes
  let valid := state.valid && !(state.bits > 0 && state.carry != 0) &&
    validRemainder codec state.digitsInGroup &&
    !(codec == .base16 && state.bits != 0) && !paddingBad
  ⟨bytes, valid⟩

/-- Fast blocks retain their last quantum; a general state takes over if a
chunk contains characters that require recovery or padding validation. -/
structure FastDecodeWindow (codec : Codec) where
  bytes : ByteArray
  bounded : bytes.size < 2 * codec.quantum

def FastDecodeWindow.empty (codec : Codec) : FastDecodeWindow codec :=
  ⟨ByteArray.empty, by simp [Codec.quantum_pos]⟩

inductive DecodeStreamState (codec : Codec) where
  | fast (pending : FastDecodeWindow codec)
  | general (state : BitsDecodeState)

/-- Decode one input chunk without retaining the whole operand. -/
def decodeStreamChunk (codec : Codec) (ignoreGarbage : Bool)
    (state : DecodeStreamState codec) (chunk : ByteArray) :
    DecodeStreamState codec × ByteArray :=
  match state with
  | .general bits =>
    let (next, output) := decodeBitsStreamChunk codec ignoreGarbage bits chunk
    (.general next, output)
  | .fast pending =>
    let input := pending.bytes ++ chunk
    let recover := fun (_ : Unit) =>
      let (next, output) := decodeBitsStreamChunk codec ignoreGarbage
        (BitsDecodeState.initial codec) input
      (DecodeStreamState.general next, output)
    let groups := input.size / codec.quantum
    if groups ≤ 1 then
      if h : input.size < 2 * codec.quantum then
        (.fast ⟨input, h⟩, ByteArray.empty)
      else recover ()
    else
      let endOffset := (groups - 1) * codec.quantum
      let completeBlocks := input.extract 0 endOffset
      let fast := match codec with
        | .base64 | .base64url => decode64Fast codec completeBlocks
        | .base32 | .base32hex => decode32Fast codec completeBlocks
        | _ => none
      let fullBytes := match codec with
        | .base64 | .base64url => endOffset / 4 * 3
        | .base32 | .base32hex => endOffset / 8 * 5
        | _ => 0
      match fast with
      | some output =>
        if output.size == fullBytes then
          let remainder := input.extract endOffset input.size
          if h : remainder.size < 2 * codec.quantum then
            (.fast ⟨remainder, h⟩, output)
          else recover ()
        else recover ()
      | none => recover ()

/-- Finish validation after the last input chunk. -/
def finishDecodeStream (codec : Codec) (ignoreGarbage : Bool)
    (state : DecodeStreamState codec) : DecodeResult :=
  match state with
  | .fast pending => decode codec ignoreGarbage pending.bytes
  | .general bits => finishBitsDecode codec bits

/-- Wrap output after `columns` bytes, appending a newline to nonempty output. -/
def wrap (input : ByteArray) (columns : Nat) : ByteArray := Id.run do
  if columns == 0 || input.isEmpty then return input
  let mut out := ByteArray.emptyWithCapacity (input.size + input.size / columns + 1)
  let mut offset := 0
  while offset < input.size do
    let count := min columns (input.size - offset)
    out := input.copySlice offset out out.size count false
    out := out.push 10
    offset := offset + count
  return out

/-- Pure state carried between bounded input reads during encoding. -/
structure EncodeStreamState (codec : Codec) (columns : Nat) where
  pending : ByteArray
  pendingBound : pending.size < codec.inputQuantum
  column : Nat
  columnBound : columns = 0 ∨ column < columns

def EncodeStreamState.empty (codec : Codec) (columns : Nat) :
    EncodeStreamState codec columns :=
  ⟨ByteArray.empty, by simp [Codec.inputQuantum_pos], 0, by omega⟩

/-- Wrap one encoded chunk while carrying its current output column. -/
private def wrapStreamChunk (columns column : Nat) (encoded : ByteArray) : Nat × ByteArray := Id.run do
  if columns == 0 then return (0, encoded)
  let mut out := ByteArray.emptyWithCapacity (encoded.size + encoded.size / columns + 2)
  let mut offset := 0
  let mut column := column % columns
  while offset < encoded.size do
    let count := min (columns - column) (encoded.size - offset)
    out := encoded.copySlice offset out out.size count false
    offset := offset + count
    column := column + count
    if column == columns then
      out := out.push 10
      column := 0
  return (column, out)

/-- Consume complete encoding blocks, retaining at most one partial block. -/
def encodeStreamChunk (codec : Codec) (columns : Nat)
    (state : EncodeStreamState codec columns) (chunk : ByteArray) :
    EncodeStreamState codec columns × ByteArray :=
  let input := state.pending ++ chunk
  let complete := input.size / codec.inputQuantum * codec.inputQuantum
  let encoded := encode codec (input.extract 0 complete)
  let pending := input.extract complete input.size
  let (rawColumn, output) := wrapStreamChunk columns state.column encoded
  let column := if columns == 0 then 0 else rawColumn % columns
  have pendingBound : pending.size < codec.inputQuantum := by
    have hq := codec.inputQuantum_pos
    simp only [pending, ByteArray.size_extract, Nat.min_self]
    rw [show input.size - complete = input.size % codec.inputQuantum by
      simpa [complete, Nat.mul_comm] using
        (Nat.mod_eq_sub input.size codec.inputQuantum).symm]
    exact Nat.mod_lt _ hq
  have columnBound : columns = 0 ∨ column < columns := by
    simp only [column]
    by_cases h : columns = 0
    · simp [h]
    · simp [h, Nat.mod_lt _ (Nat.pos_of_ne_zero h)]
  (⟨pending, pendingBound, column, columnBound⟩, output)

/-- Flush the final partial input block and terminate a nonempty output line. -/
def finishEncodeStream (codec : Codec) (columns : Nat)
    (state : EncodeStreamState codec columns) : ByteArray :=
  let encoded := encode codec state.pending
  let (column, output) := wrapStreamChunk columns state.column encoded
  if columns > 0 && column > 0 then output.push 10 else output

theorem wrap_empty (columns : Nat) : wrap ByteArray.empty columns = ByteArray.empty := by
  simp [wrap, ByteArray.isEmpty]

theorem base64_abc : encode .base64 "abc".toUTF8 = "YWJj".toUTF8 := by
  native_decide

theorem base32_abc : encode .base32 "abc".toUTF8 = "MFRGG===".toUTF8 := by
  native_decide

theorem base64_abc_decode : (decode .base64 false "YWJj".toUTF8).bytes = "abc".toUTF8 := by
  native_decide

theorem base32_abc_decode : (decode .base32 false "MFRGG===".toUTF8).bytes = "abc".toUTF8 := by
  native_decide

/-- Splitting an encoded quantum across reads does not lose its digits. -/
theorem base64_stream_split :
    let (first, a) := decodeStreamChunk .base64 false (.fast (FastDecodeWindow.empty .base64)) "YW".toUTF8
    let (last, b) := decodeStreamChunk .base64 false first "Jj".toUTF8
    a ++ b ++ (finishDecodeStream .base64 false last).bytes = "abc".toUTF8 := by
  native_decide

set_option maxRecDepth 2048 in
/-- The general path retains its bit carry across a newline and a read boundary. -/
theorem base64_general_stream_split :
    let (first, a) := decodeBitsStreamChunk .base64 false
      (BitsDecodeState.initial .base64) "YW\n".toUTF8
    let (last, b) := decodeBitsStreamChunk .base64 false first "Jj".toUTF8
    a ++ b ++ (finishBitsDecode .base64 last).bytes = "abc".toUTF8 := by
  native_decide


/-- The two non-power-of-two formats supported by `basenc`. -/
inductive Format where
  | power (codec : Codec)
  | base58
  | z85
  deriving BEq, DecidableEq

private def base58Alphabet : Vector UInt8 58 :=
  Vector.mk "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".toUTF8.data (by decide)

private def z85Alphabet : Vector UInt8 85 :=
  Vector.mk "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#".toUTF8.data (by decide)

private def base58Digits (number : Nat) : List UInt8 :=
  if number == 0 then [] else go number []
where
  go (number : Nat) (acc : List UInt8) : List UInt8 :=
    if h : number = 0 then acc
    else go (number / 58) (base58Alphabet[number % 58]'(by omega) :: acc)
  termination_by number
  decreasing_by
    apply Nat.div_lt_self
    · omega
    · decide

private def base58Encode (input : ByteArray) : ByteArray := Id.run do
  let mut number := 0
  let mut leading := 0
  let mut nonzero := false
  for byte in input do
    if !nonzero && byte == 0 then leading := leading + 1
    else nonzero := true
    number := number * 256 + byte.toNat
  let digits := List.replicate leading (49 : UInt8) ++
    base58Digits number
  return ByteArray.mk digits.toArray

structure Base58DecodeState where
  number : Nat := 0
  leading : Nat := 0
  nonzero : Bool := false
  valid : Bool := true
  halted : Bool := false

/-- Base58 needs a growing positional accumulator, but no input byte buffer. -/
def base58DecodeChunk (ignoreGarbage : Bool) (initial : Base58DecodeState)
    (input : ByteArray) : Base58DecodeState × ByteArray := Id.run do
  let mut state := initial
  for byte in input do
    if state.halted then break
    if isNewline byte then continue
    match base58Alphabet.toList.idxOf? byte with
    | some digit =>
      let leading := if !state.nonzero && digit == 0 then state.leading + 1 else state.leading
      let nonzero := state.nonzero || digit != 0
      state := { state with number := state.number * 58 + digit, leading := leading, nonzero := nonzero }
    | none =>
      if !ignoreGarbage then state := { state with valid := false, halted := true }
  return (state, ByteArray.empty)

def finishBase58Decode (state : Base58DecodeState) : DecodeResult := Id.run do
  let mut number := state.number
  let mut bytes : List UInt8 := []
  while number > 0 do
    bytes := UInt8.ofNat (number % 256) :: bytes
    number := number / 256
  return ⟨ByteArray.mk ((List.replicate state.leading (0 : UInt8) ++ bytes).toArray), state.valid⟩

private def base58Decode (input : ByteArray) (ignoreGarbage : Bool) : DecodeResult :=
  let (state, _) := base58DecodeChunk ignoreGarbage {} input
  finishBase58Decode state

private def z85Encode (input : ByteArray) : Option ByteArray := Id.run do
  if input.size % 4 != 0 then return none
  let mut out := ByteArray.empty
  for index in List.finRange (input.size / 4) do
    let i := index.val
    let j := i * 4
    let mut n := (input[j]'(by omega)).toNat * 16777216 +
      (input[j + 1]'(by omega)).toNat * 65536 +
      (input[j + 2]'(by omega)).toNat * 256 +
      (input[j + 3]'(by omega)).toNat
    let mut block : Vector UInt8 5 := Vector.replicate 5 0
    for index in List.finRange 5 do
      let k := index.val
      block := block.set (4 - k) (z85Alphabet[n % 85]'(by omega)) (by omega)
      n := n / 85
    out := out ++ ByteArray.mk block.toArray
  return some out

structure Z85DecodeState where
  value : Nat := 0
  count : Nat := 0
  valid : Bool := true
  halted : Bool := false

/-- Z85 emits complete four-byte blocks as five digits become available. -/
def z85DecodeChunk (ignoreGarbage : Bool) (initial : Z85DecodeState)
    (input : ByteArray) : Z85DecodeState × ByteArray := Id.run do
  let mut state := initial
  let mut out := ByteArray.empty
  for byte in input do
    if state.halted then break
    if isNewline byte then continue
    match z85Alphabet.toList.idxOf? byte with
    | none =>
      if !ignoreGarbage then state := { state with valid := false, halted := true }
    | some digit =>
      let value := state.value * 85 + digit
      let count := state.count + 1
      if count == 5 then
        if value >= 2 ^ 32 then
          state := { state with valid := false, halted := true }
          break
        out := out.push (UInt8.ofNat (value / 16777216))
        out := out.push (UInt8.ofNat (value / 65536))
        out := out.push (UInt8.ofNat (value / 256))
        out := out.push (UInt8.ofNat value)
        state := { state with value := 0, count := 0 }
      else state := { state with value := value, count := count }
  return (state, out)

def finishZ85Decode (state : Z85DecodeState) : Bool :=
  state.valid && state.count == 0

private def z85Decode (input : ByteArray) (ignoreGarbage : Bool) : DecodeResult :=
  let (state, out) := z85DecodeChunk ignoreGarbage {} input
  ⟨out, finishZ85Decode state⟩

theorem base58_stream_split :
    let (first, _) := base58DecodeChunk false {} "Zi".toUTF8
    let (last, _) := base58DecodeChunk false first "Ca".toUTF8
    (finishBase58Decode last).bytes = "abc".toUTF8 := by
  native_decide

theorem z85_stream_split :
    let (first, a) := z85DecodeChunk false {} "vp".toUTF8
    let (_, b) := z85DecodeChunk false first "A.S".toUTF8
    a ++ b = "abcd".toUTF8 := by
  native_decide

/-- Encode with any `basenc` format, rejecting a partial Z85 block. -/
def encodeFormat (format : Format) (input : ByteArray) : Option ByteArray :=
  match format with
  | .power codec => some (encode codec input)
  | .base58 => some (base58Encode input)
  | .z85 => z85Encode input

/-- Decode with any `basenc` format. -/
def decodeFormat (format : Format) (ignoreGarbage : Bool) (input : ByteArray) : DecodeResult :=
  match format with
  | .power codec => decode codec ignoreGarbage input
  | .base58 => base58Decode input ignoreGarbage
  | .z85 => z85Decode input ignoreGarbage

end Lutils.BaseEncoding
