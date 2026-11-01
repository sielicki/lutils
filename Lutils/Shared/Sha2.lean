import Lutils.Shared.Common

namespace Lutils.Sha2

/-- The two SHA-2/32 variants share a compression function and differ only in IV and output length. -/
inductive Variant where
  | sha224 | sha256
  deriving BEq, DecidableEq

/-- Eight 32-bit chaining words. -/
abbrev State := Vector UInt32 8

/-- Sixty-four words in an expanded message block. -/
abbrev Schedule := Vector UInt32 64

/-- A view of one complete 512-bit block in a byte array. -/
structure Block where
  bytes : ByteArray
  offset : Nat
  inBounds : offset + 64 ≤ bytes.size

private def roundConstants : Schedule := #v[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

private def initial : Variant → State
  | .sha256 => #v[0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
  | .sha224 => #v[0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939,
                  0xffc00b31, 0x68581511, 0x64f98fa7, 0xbefa4fa4]

@[inline] private def rotr (x : UInt32) (n : Nat) : UInt32 :=
  (x >>> UInt32.ofNat n) ||| (x <<< UInt32.ofNat (32 - n))

private def big0 (x : UInt32) : UInt32 := rotr x 2 ^^^ rotr x 13 ^^^ rotr x 22
private def big1 (x : UInt32) : UInt32 := rotr x 6 ^^^ rotr x 11 ^^^ rotr x 25
private def small0 (x : UInt32) : UInt32 := rotr x 7 ^^^ rotr x 18 ^^^ (x >>> 3)
private def small1 (x : UInt32) : UInt32 := rotr x 17 ^^^ rotr x 19 ^^^ (x >>> 10)

/-- FIPS 180-4's 512-bit block compression, using modular `UInt32` arithmetic. -/
def compress (state : State) (block : Block) : State := Id.run do
  let mut schedule : Schedule := Vector.replicate 64 0
  for index in List.finRange 16 do
    let i := index.val
    let j := block.offset + 4 * i
    let word := (UInt32.ofNat (block.bytes[j]'(by have h := block.inBounds; omega)).toNat <<< 24) |||
      (UInt32.ofNat (block.bytes[j + 1]'(by have h := block.inBounds; omega)).toNat <<< 16) |||
      (UInt32.ofNat (block.bytes[j + 2]'(by have h := block.inBounds; omega)).toNat <<< 8) |||
      UInt32.ofNat (block.bytes[j + 3]'(by have h := block.inBounds; omega)).toNat
    schedule := schedule.set i word (by omega)
  for index in List.finRange 48 do
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
  for index in List.finRange 64 do
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

/-- Number of zero bytes before the eight-byte length footer. -/
def zeroPadding (n : Nat) : Nat := (119 - n % 64) % 64

/-- The padding count puts the footer at the end of a 64-byte block. -/
theorem zeroPadding_mod (n : Nat) : (n + 1 + zeroPadding n + 8) % 64 = 0 := by
  unfold zeroPadding
  omega

private def lengthBytes (n : Nat) : ByteArray :=
  let bits := UInt64.ofNat n * 8
  ByteArray.mk #[
    (bits >>> 56).toUInt8, (bits >>> 48).toUInt8,
    (bits >>> 40).toUInt8, (bits >>> 32).toUInt8,
    (bits >>> 24).toUInt8, (bits >>> 16).toUInt8,
    (bits >>> 8).toUInt8, bits.toUInt8]

/-- Append one bit, zero padding, and the original bit length modulo 2^64. -/
def pad (input : ByteArray) : ByteArray :=
  input.push 0x80 ++ ByteArray.mk (Array.replicate (zeroPadding input.size) 0) ++
    lengthBytes input.size

theorem pad_size_mod (input : ByteArray) : (pad input).size % 64 = 0 := by
  have hzeros : (ByteArray.mk (Array.replicate (zeroPadding input.size) (0 : UInt8))).size =
      zeroPadding input.size := by exact Array.size_replicate
  have hlength : (lengthBytes input.size).size = 8 := by
    simp only [lengthBytes, ByteArray.size]
    rfl
  simpa only [pad, ByteArray.size_append, ByteArray.size_push, hzeros, hlength] using
    zeroPadding_mod input.size

private def hexDigits : Vector Char 16 :=
  #v['0', '1', '2', '3', '4', '5', '6', '7',
     '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']
private def hexByte (b : UInt8) : String :=
  String.singleton (hexDigits[b.toNat / 16]'(by have h := UInt8.toNat_lt b; omega)) ++
  String.singleton (hexDigits[b.toNat % 16]'(by omega))

private def hexWord (w : UInt32) : String := Id.run do
  let mut out := ""
  for i in [0:4] do
    out := out ++ hexByte (w >>> UInt32.ofNat (8 * (3 - i))).toUInt8
  return out

/-- Compute the SHA-224 or SHA-256 digest, returning lowercase hexadecimal. -/
def digest (variant : Variant) (input : ByteArray) : String := Id.run do
  let padded := pad input
  let mut state := initial variant
  for index in List.finRange (padded.size / 64) do
    let offset := index.val * 64
    let block : Block := ⟨padded, offset, by
      have h := pad_size_mod input
      omega⟩
    state := compress state block
  let words := if variant == .sha224 then 7 else 8
  return String.join ((state.toList.take words).map hexWord)

/-- Executable checks of the FIPS 180-4 short-message vectors. -/
theorem sha256_empty : digest .sha256 "".toUTF8 =
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" := by
  native_decide

theorem sha256_abc : digest .sha256 "abc".toUTF8 =
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" := by
  native_decide

theorem sha224_empty : digest .sha224 "".toUTF8 =
    "d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f" := by
  native_decide

theorem sha224_abc : digest .sha224 "abc".toUTF8 =
    "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7" := by
  native_decide

end Lutils.Sha2
