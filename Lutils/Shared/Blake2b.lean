/- RFC 7693 BLAKE2b, with pure incremental state and fixed-width rounds. -/
import Lutils.Shared.Common

namespace Lutils.Blake2b

/-- BLAKE2b's output length is one through sixty-four bytes. -/
structure DigestSize where
  bytes : Nat
  positive : 0 < bytes
  bounded : bytes ≤ 64

def DigestSize.default : DigestSize := ⟨64, by decide, by decide⟩

def DigestSize.ofBits (bits : Nat) : Option DigestSize :=
  if bits == 0 then some .default
  else if h : bits % 8 = 0 ∧ 8 ≤ bits ∧ bits ≤ 512 then
    some ⟨bits / 8, by omega, by omega⟩
  else none

theorem DigestSize.ofBits_zero : DigestSize.ofBits 0 = some .default := by
  simp [DigestSize.ofBits]

abbrev Chain := Vector UInt64 8
abbrev Working := Vector UInt64 16
abbrev Message := Vector UInt64 16

private def iv : Chain := #v[
  0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
  0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179]

private def sigma : Vector (Vector (Fin 16) 16) 10 := #v[
  #v[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  #v[14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
  #v[11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
  #v[7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
  #v[9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
  #v[2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
  #v[12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
  #v[13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
  #v[6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
  #v[10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0]]

@[inline] private def rotr (word : UInt64) (count : Nat) : UInt64 :=
  (word >>> UInt64.ofNat count) ||| (word <<< UInt64.ofNat (64 - count))

/-- One BLAKE2b G mixing operation. All lanes and message indices are bounded. -/
@[inline] private def mix (v : Working) (a b c d : Fin 16) (x y : UInt64) : Working :=
  let a₁ := v[a] + v[b] + x
  let d₁ := rotr (v[d] ^^^ a₁) 32
  let c₁ := v[c] + d₁
  let b₁ := rotr (v[b] ^^^ c₁) 24
  let a₂ := a₁ + b₁ + y
  let d₂ := rotr (d₁ ^^^ a₂) 16
  let c₂ := c₁ + d₂
  let b₂ := rotr (b₁ ^^^ c₂) 63
  (((v.set a a₂).set b b₂).set c c₂).set d d₂

@[inline] private def round (v : Working) (message : Message) (index : Fin 12) : Working :=
  let s := sigma.get ⟨index.val % 10, by omega⟩
  let v := mix v 0 4 8 12 (message.get (s.get 0)) (message.get (s.get 1))
  let v := mix v 1 5 9 13 (message.get (s.get 2)) (message.get (s.get 3))
  let v := mix v 2 6 10 14 (message.get (s.get 4)) (message.get (s.get 5))
  let v := mix v 3 7 11 15 (message.get (s.get 6)) (message.get (s.get 7))
  let v := mix v 0 5 10 15 (message.get (s.get 8)) (message.get (s.get 9))
  let v := mix v 1 6 11 12 (message.get (s.get 10)) (message.get (s.get 11))
  let v := mix v 2 7 8 13 (message.get (s.get 12)) (message.get (s.get 13))
  mix v 3 4 9 14 (message.get (s.get 14)) (message.get (s.get 15))

private def wordAt (bytes : ByteArray) (offset : Nat) (word : Fin 16) : UInt64 :=
  let base := offset + 8 * word.val
  let read (index : Nat) := UInt64.ofNat (bytes.data.getD (base + index) 0).toNat
  read 0 ||| (read 1 <<< 8) ||| (read 2 <<< 16) ||| (read 3 <<< 24) |||
    (read 4 <<< 32) ||| (read 5 <<< 40) ||| (read 6 <<< 48) ||| (read 7 <<< 56)

private def messageAt (bytes : ByteArray) (offset : Nat) : Message :=
  Vector.ofFn (fun index => wordAt bytes offset index)

/-- Compress one block; `total` counts bytes through this block. -/
def compress (chain : Chain) (bytes : ByteArray) (offset total : Nat)
    (final : Bool) : Chain := Id.run do
  let message := messageAt bytes offset
  let mut v : Working := #v[
    chain[0], chain[1], chain[2], chain[3], chain[4], chain[5], chain[6], chain[7],
    iv[0], iv[1], iv[2], iv[3], iv[4], iv[5], iv[6], iv[7]]
  v := v.set 12 (v[12] ^^^ UInt64.ofNat total)
  v := v.set 13 (v[13] ^^^ UInt64.ofNat (total >>> 64))
  if final then v := v.set 14 (~~~v[14])
  for index in List.finRange 12 do
    v := round v message index
  return #v[
    chain[0] ^^^ v[0] ^^^ v[8], chain[1] ^^^ v[1] ^^^ v[9],
    chain[2] ^^^ v[2] ^^^ v[10], chain[3] ^^^ v[3] ^^^ v[11],
    chain[4] ^^^ v[4] ^^^ v[12], chain[5] ^^^ v[5] ^^^ v[13],
    chain[6] ^^^ v[6] ^^^ v[14], chain[7] ^^^ v[7] ^^^ v[15]]

structure State where
  size : DigestSize
  chain : Chain
  processed : Nat := 0
  pending : ByteArray := ByteArray.empty

def State.initial (size : DigestSize) : State :=
  { size, chain := iv.set 0 (iv[0] ^^^ UInt64.ofNat (0x01010000 + size.bytes)) }

/-- Keep the last block pending because only it receives the final flag. -/
def State.update (state : State) (chunk : ByteArray) : State := Id.run do
  let combined := state.pending ++ chunk
  let mut chain := state.chain
  let mut processed := state.processed
  let mut offset := 0
  while offset + 128 < combined.size do
    processed := processed + 128
    chain := compress chain (combined.extract offset (offset + 128)) 0 processed false
    offset := offset + 128
  return { state with chain, processed, pending := combined.extract offset combined.size }

/-- Turn the pending partial block into the final padded compression block. -/
def State.finish (state : State) : ByteArray := Id.run do
  let finalBlock := state.pending ++
    ByteArray.mk (Array.replicate (128 - state.pending.size) 0)
  let chain := compress state.chain finalBlock 0 (state.processed + state.pending.size) true
  let mut out := ByteArray.empty
  for word in chain do
    for index in List.finRange 8 do
      out := out.push (word >>> UInt64.ofNat (8 * index.val)).toUInt8
  return out.extract 0 state.size.bytes

/-- A pure one-shot wrapper useful for laws and test vectors. -/
def digest (size : DigestSize) (bytes : ByteArray) : String :=
  hexEncode ((State.initial size).update bytes).finish

/-- RFC 7693's empty-message BLAKE2b-512 vector. -/
theorem digest_empty : digest .default ByteArray.empty =
    "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce" := by
  native_decide

/-- RFC 7693's `abc` BLAKE2b-512 vector. -/
theorem digest_abc : digest .default "abc".toUTF8 =
    "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923" := by
  native_decide

/-- Incremental updates preserve the `abc` digest across this split. -/
theorem digest_abc_split :
    hexEncode (((State.initial .default).update "a".toUTF8).update "bc".toUTF8).finish =
      digest .default "abc".toUTF8 := by
  native_decide

/-- The 256-bit output is parameterized before compression, not truncated. -/
theorem digest_abc_256 :
    digest ⟨32, by decide, by decide⟩ "abc".toUTF8 =
      "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319" := by
  native_decide

/-- A split across the final-block boundary hashes identically. -/
theorem digest_block_split :
    hexEncode (State.finish (State.update
      (State.update (State.initial .default) (ByteArray.mk (Array.replicate 128 97)))
      (ByteArray.mk #[97]))) =
      digest .default (ByteArray.mk (Array.replicate 129 97)) := by
  native_decide

end Lutils.Blake2b
