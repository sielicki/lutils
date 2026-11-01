import Lutils.Shared.Common

namespace Lutils.Md5

abbrev State := Vector UInt32 4

private def roundConstants : Vector UInt32 64 := #v[
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
  0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
  0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
  0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
  0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
  0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
  0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
  0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
  0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
  0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
  0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
  0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
  0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
  0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391]

private def shifts : Vector Nat 64 := #v[
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21]

private def initial : State := #v[0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476]

@[inline] private def rotl (x : UInt32) (n : Nat) : UInt32 :=
  (x <<< UInt32.ofNat n) ||| (x >>> UInt32.ofNat (32 - n))

private def wordAt (bytes : ByteArray) (j : Nat) : UInt32 := Id.run do
  let mut word : UInt32 := 0
  for k in [0:4] do
    word := word ||| (UInt32.ofNat (bytes.data.getD (j + k) 0).toNat <<< UInt32.ofNat (8 * k))
  return word

/-- RFC 1321's 512-bit block compression, using modular `UInt32` arithmetic.
MD5 reads each message word little-endian, unlike the SHA family. -/
def compress (state : State) (bytes : ByteArray) (offset : Nat) : State := Id.run do
  let mut a := state[0]
  let mut b := state[1]
  let mut c := state[2]
  let mut d := state[3]
  for index in List.finRange 64 do
    let i := index.val
    let (f, g) : UInt32 × Nat :=
      if i < 16 then (((b &&& c) ^^^ ((~~~b) &&& d)), i)
      else if i < 32 then (((d &&& b) ^^^ ((~~~d) &&& c)), (5 * i + 1) % 16)
      else if i < 48 then ((b ^^^ c ^^^ d), (3 * i + 5) % 16)
      else ((c ^^^ (b ||| ~~~d)), (7 * i) % 16)
    let sum := a + f + roundConstants[i] + wordAt bytes (offset + 4 * g)
    a := d
    d := c
    c := b
    b := b + rotl sum shifts[i]
  return #v[state[0] + a, state[1] + b, state[2] + c, state[3] + d]

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
    out := out.push (bits >>> UInt64.ofNat (8 * i)).toUInt8
  return out

/-- Append one bit, zero padding, and the little-endian bit length. -/
def pad (input : ByteArray) : ByteArray :=
  input.push 0x80 ++ ByteArray.mk (Array.replicate (zeroPadding input.size) 0) ++
    lengthBytes input.size

private def wordBytes (w : UInt32) : ByteArray := Id.run do
  let mut out := ByteArray.empty
  for i in [0:4] do
    out := out.push (w >>> UInt32.ofNat (8 * i)).toUInt8
  return out

/-- Compute the MD5 digest, returning lowercase hexadecimal. -/
def digest (input : ByteArray) : String := Id.run do
  let padded := pad input
  let mut state := initial
  for index in List.finRange (padded.size / 64) do
    state := compress state padded (index.val * 64)
  let bytes := state.toList.foldl (fun acc w => acc ++ wordBytes w) ByteArray.empty
  return hexEncode bytes

/-- Executable checks of the RFC 1321 test suite's short inputs. -/
theorem md5_empty : digest "".toUTF8 =
    "d41d8cd98f00b204e9800998ecf8427e" := by
  native_decide

theorem md5_abc : digest "abc".toUTF8 =
    "900150983cd24fb0d6963f7d28e17f72" := by
  native_decide

end Lutils.Md5
