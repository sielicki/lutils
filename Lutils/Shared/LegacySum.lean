import Lutils.Shared.Common

namespace Lutils.LegacySum

/-- One byte of the POSIX `cksum` CRC: polynomial `0x04c11db7`, MSB first. -/
def crcStep (crc : UInt32) (byte : UInt8) : UInt32 := Id.run do
  let mut c := crc ^^^ (UInt32.ofNat byte.toNat <<< 24)
  for _ in [0:8] do
    c := if c &&& 0x80000000 != 0 then (c <<< 1) ^^^ 0x04c11db7 else c <<< 1
  return c

/-- The POSIX `cksum` CRC. The message length is fed in little-endian after
the data, and the final value is complemented; empty input gives `2^32 - 1`. -/
def cksumCrc (data : ByteArray) : UInt32 := Id.run do
  let mut crc : UInt32 := 0
  for byte in data do
    crc := crcStep crc byte
  let mut len := data.size
  while 0 < len do
    crc := crcStep crc (UInt8.ofNat len)
    len := len >>> 8
  return ~~~crc

/-- One byte of the reflected CRC-32 used by `zlib` (GNU `crc32b`). -/
def crc32bStep (crc : UInt32) (byte : UInt8) : UInt32 := Id.run do
  let mut c := crc ^^^ UInt32.ofNat byte.toNat
  for _ in [0:8] do
    c := if c &&& 1 != 0 then (c >>> 1) ^^^ 0xedb88320 else c >>> 1
  return c

/-- Standard reflected CRC-32: seeded and finished with all ones. -/
def crc32b (data : ByteArray) : UInt32 := Id.run do
  let mut crc : UInt32 := 0xffffffff
  for byte in data do
    crc := crc32bStep crc byte
  return ~~~crc

/-- The historic BSD checksum: rotate the 16-bit sum right before adding
each byte, so byte order matters. -/
def bsdChecksum (data : ByteArray) : Nat := Id.run do
  let mut sum : Nat := 0
  for byte in data do
    sum := (sum >>> 1) + ((sum &&& 1) <<< 15)
    sum := (sum + byte.toNat) &&& 0xffff
  return sum

/-- The System V checksum: the byte sum folded down to 16 bits twice. -/
def sysvChecksum (data : ByteArray) : Nat := Id.run do
  let mut sum : Nat := 0
  for byte in data do
    sum := sum + byte.toNat
  let folded := (sum &&& 0xffff) + (sum >>> 16)
  return (folded &&& 0xffff) + (folded >>> 16)

/-- Block counts are ceiling divisions; empty input has zero blocks. -/
def bsdBlocks (size : Nat) : Nat := (size + 1023) / 1024

def sysvBlocks (size : Nat) : Nat := (size + 511) / 512

theorem bsdBlocks_empty : bsdBlocks 0 = 0 := rfl

theorem sysvBlocks_empty : sysvBlocks 0 = 0 := rfl

/-- GNU's BSD line: zero-padded 5-digit checksum, right-aligned block count. -/
def renderBsd (data : ByteArray) (name : Option String) (zero : Bool) : String :=
  let body := s!"{padLeft 5 '0' (toString (bsdChecksum data))} {padLeft 5 ' ' (toString (bsdBlocks data.size))}"
  (match name with
   | some n => body ++ " " ++ n
   | none => body) ++ if zero then "\x00" else "\n"

/-- GNU's System V line: both numbers in plain decimal. -/
def renderSysv (data : ByteArray) (name : Option String) (zero : Bool) : String :=
  let body := s!"{sysvChecksum data} {sysvBlocks data.size}"
  (match name with
   | some n => body ++ " " ++ n
   | none => body) ++ if zero then "\x00" else "\n"

end Lutils.LegacySum
