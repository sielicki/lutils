import Lutils.Shared.Common

namespace Lutils.Sha1

abbrev State := Vector UInt32 5
abbrev Schedule := Vector UInt32 80

private def initial : State :=
  #v[0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0]

@[inline] private def rotl (x : UInt32) (n : Nat) : UInt32 :=
  (x <<< UInt32.ofNat n) ||| (x >>> UInt32.ofNat (32 - n))

private def wordAt (bytes : ByteArray) (j : Nat) : UInt32 := Id.run do
  let mut word : UInt32 := 0
  for k in [0:4] do
    word := (word <<< 8) ||| UInt32.ofNat (bytes.data.getD (j + k) 0).toNat
  return word

/-- FIPS 180-1's 512-bit block compression, using modular `UInt32` arithmetic. -/
def compress (state : State) (bytes : ByteArray) (offset : Nat) : State := Id.run do
  let mut schedule : Schedule := Vector.replicate 80 0
  for index in List.finRange 16 do
    let i := index.val
    schedule := schedule.set i (wordAt bytes (offset + 4 * i)) (by omega)
  for index in List.finRange 64 do
    let i := index.val + 16
    let word := rotl (schedule[i - 3] ^^^ schedule[i - 8] ^^^
      schedule[i - 14] ^^^ schedule[i - 16]) 1
    schedule := schedule.set i word (by omega)
  let mut a := state[0]
  let mut b := state[1]
  let mut c := state[2]
  let mut d := state[3]
  let mut e := state[4]
  for index in List.finRange 80 do
    let i := index.val
    let (f, k) : UInt32 × UInt32 :=
      if i < 20 then (((b &&& c) ^^^ ((~~~b) &&& d)), 0x5a827999)
      else if i < 40 then ((b ^^^ c ^^^ d), 0x6ed9eba1)
      else if i < 60 then (((b &&& c) ^^^ (b &&& d) ^^^ (c &&& d)), 0x8f1bbcdc)
      else ((b ^^^ c ^^^ d), 0xca62c1d6)
    let temp := rotl a 5 + f + e + k + schedule[i]
    e := d
    d := c
    c := rotl b 30
    b := a
    a := temp
  return #v[state[0] + a, state[1] + b, state[2] + c, state[3] + d, state[4] + e]

/-- Number of zero bytes before the eight-byte length footer. -/
def zeroPadding (n : Nat) : Nat := (119 - n % 64) % 64

/-- The padding count puts the footer at the end of a 64-byte block. -/
theorem zeroPadding_mod (n : Nat) : (n + 1 + zeroPadding n + 8) % 64 = 0 := by
  unfold zeroPadding
  omega

private def lengthBytes (n : Nat) : ByteArray := Id.run do
  let bits := UInt64.ofNat n * 8
  let mut out := ByteArray.empty
  for i in [0:8] do
    out := out.push (bits >>> UInt64.ofNat (8 * (7 - i))).toUInt8
  return out

/-- Append one bit, zero padding, and the original bit length modulo 2^64. -/
def pad (input : ByteArray) : ByteArray :=
  input.push 0x80 ++ ByteArray.mk (Array.replicate (zeroPadding input.size) 0) ++
    lengthBytes input.size

private def wordBytes (w : UInt32) : ByteArray := Id.run do
  let mut out := ByteArray.empty
  for i in [0:4] do
    out := out.push (w >>> UInt32.ofNat (8 * (3 - i))).toUInt8
  return out

/-- Compute the SHA-1 digest, returning lowercase hexadecimal. -/
def digest (input : ByteArray) : String := Id.run do
  let padded := pad input
  let mut state := initial
  for index in List.finRange (padded.size / 64) do
    state := compress state padded (index.val * 64)
  let bytes := state.toList.foldl (fun acc w => acc ++ wordBytes w) ByteArray.empty
  return hexEncode bytes

/-- Executable checks of the FIPS 180-1 short-message vectors. -/
theorem sha1_empty : digest "".toUTF8 =
    "da39a3ee5e6b4b0d3255bfef95601890afd80709" := by
  native_decide

theorem sha1_abc : digest "abc".toUTF8 =
    "a9993e364706816aba3e25717850c26c9cd0d89d" := by
  native_decide

end Lutils.Sha1
