import Lutils.Shared.Common

namespace Lutils.Sha512

/-- The SHA-2/64 variants share a compression function and differ only in IV
and output length. -/
inductive Variant where
  | sha384 | sha512
  deriving BEq, DecidableEq

abbrev State := Vector UInt64 8
abbrev Schedule := Vector UInt64 80

private def roundConstants : Vector UInt64 80 := #v[
  0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
  0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
  0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
  0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
  0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
  0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
  0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
  0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
  0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
  0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
  0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
  0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
  0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
  0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
  0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
  0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
  0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
  0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
  0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
  0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817]

private def initial : Variant → State
  | .sha512 => #v[0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
                  0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179]
  | .sha384 => #v[0xcbbb9d5dc1059ed8, 0x629a292a367cd507, 0x9159015a3070dd17, 0x152fecd8f70e5939,
                  0x67332667ffc00b31, 0x8eb44a8768581511, 0xdb0c2e0d64f98fa7, 0x47b5481dbefa4fa4]

@[inline] private def rotr (x : UInt64) (n : Nat) : UInt64 :=
  (x >>> UInt64.ofNat n) ||| (x <<< UInt64.ofNat (64 - n))

private def big0 (x : UInt64) : UInt64 := rotr x 28 ^^^ rotr x 34 ^^^ rotr x 39
private def big1 (x : UInt64) : UInt64 := rotr x 14 ^^^ rotr x 18 ^^^ rotr x 41
private def small0 (x : UInt64) : UInt64 := rotr x 1 ^^^ rotr x 8 ^^^ (x >>> 7)
private def small1 (x : UInt64) : UInt64 := rotr x 19 ^^^ rotr x 61 ^^^ (x >>> 6)

private def wordAt (bytes : ByteArray) (j : Nat) : UInt64 := Id.run do
  let mut word : UInt64 := 0
  for k in [0:8] do
    word := (word <<< 8) ||| UInt64.ofNat (bytes.data.getD (j + k) 0).toNat
  return word

/-- FIPS 180-4's 1024-bit block compression, using modular `UInt64` arithmetic. -/
def compress (state : State) (bytes : ByteArray) (offset : Nat) : State := Id.run do
  let mut schedule : Schedule := Vector.replicate 80 0
  for index in List.finRange 16 do
    let i := index.val
    schedule := schedule.set i (wordAt bytes (offset + 8 * i)) (by omega)
  for index in List.finRange 64 do
    let i := index.val + 16
    let word := small1 schedule[i - 2] + schedule[i - 7] +
      small0 schedule[i - 15] + schedule[i - 16]
    schedule := schedule.set i word (by omega)
  let mut a := state[0]
  let mut b := state[1]
  let mut c := state[2]
  let mut d := state[3]
  let mut e := state[4]
  let mut f := state[5]
  let mut g := state[6]
  let mut h := state[7]
  for index in List.finRange 80 do
    let i := index.val
    let t1 := h + big1 e + ((e &&& f) ^^^ ((~~~e) &&& g)) +
      roundConstants[i] + schedule[i]
    let t2 := big0 a + ((a &&& b) ^^^ (a &&& c) ^^^ (b &&& c))
    h := g
    g := f
    f := e
    e := d + t1
    d := c
    c := b
    b := a
    a := t1 + t2
  return #v[state[0] + a, state[1] + b, state[2] + c, state[3] + d,
           state[4] + e, state[5] + f, state[6] + g, state[7] + h]

/-- Number of zero bytes before the sixteen-byte length footer. -/
def zeroPadding (n : Nat) : Nat := (239 - n % 128) % 128

/-- The padding count puts the footer at the end of a 128-byte block. -/
theorem zeroPadding_mod (n : Nat) : (n + 1 + zeroPadding n + 16) % 128 = 0 := by
  unfold zeroPadding
  omega

private def lengthBytes (n : Nat) : ByteArray := Id.run do
  let bits := n * 8
  let mut out := ByteArray.empty
  for i in [0:16] do
    out := out.push (UInt8.ofNat (bits >>> (8 * (15 - i))))
  return out

/-- Append one bit, zero padding, and the original bit length. -/
def pad (input : ByteArray) : ByteArray :=
  input.push 0x80 ++ ByteArray.mk (Array.replicate (zeroPadding input.size) 0) ++
    lengthBytes input.size

private def wordBytes (w : UInt64) : ByteArray := Id.run do
  let mut out := ByteArray.empty
  for i in [0:8] do
    out := out.push (w >>> UInt64.ofNat (8 * (7 - i))).toUInt8
  return out

/-- Compute the SHA-384 or SHA-512 digest, returning lowercase hexadecimal. -/
def digest (variant : Variant) (input : ByteArray) : String := Id.run do
  let padded := pad input
  let mut state := initial variant
  for index in List.finRange (padded.size / 128) do
    state := compress state padded (index.val * 128)
  let words := if variant == .sha384 then 6 else 8
  let bytes := (state.toList.take words).foldl (fun acc w => acc ++ wordBytes w) ByteArray.empty
  return hexEncode bytes

/-- Executable checks of the FIPS 180-4 short-message vectors. -/
theorem sha512_empty : digest .sha512 "".toUTF8 =
    "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e" := by
  native_decide

theorem sha512_abc : digest .sha512 "abc".toUTF8 =
    "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f" := by
  native_decide

theorem sha384_empty : digest .sha384 "".toUTF8 =
    "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b" := by
  native_decide

theorem sha384_abc : digest .sha384 "abc".toUTF8 =
    "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7" := by
  native_decide

end Lutils.Sha512
