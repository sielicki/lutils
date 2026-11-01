/- Bounded reading of newline- or NUL-terminated byte records. -/
import Lutils.Shared.Common

namespace Lutils

/-- Record content without its delimiter; it may be the unterminated final record. -/
structure DelimitedRecord where
  bytes : ByteArray

/-- A fixed read buffer and at most one pending record. -/
structure DelimitedReader where
  handle : IO.FS.Stream
  buffer : ByteArray := ByteArray.empty
  cursor : Nat := 0
  pending : ByteArray := ByteArray.empty
  ended : Bool := false
  terminator : UInt8 := 10
  chunkSize : USize := 64 * 1024

private def findDelimiter (buffer : ByteArray) (start : Nat)
    (terminator : UInt8) : Option Nat := Id.run do
  for h : i in [start:buffer.size] do
    if buffer[i] == terminator then return some i
  return none

/-- Return the next record, including an unterminated final record once. -/
def DelimitedReader.next (reader : DelimitedReader) :
    IO (DelimitedReader × Option DelimitedRecord) := do
  let mut reader := reader
  repeat
    if let some index := findDelimiter reader.buffer reader.cursor reader.terminator then
      let fragment := reader.buffer.extract reader.cursor index
      let bytes := if reader.pending.isEmpty then fragment
        else reader.pending.fastAppend fragment
      reader := { reader with cursor := index + 1, pending := ByteArray.empty }
      return (reader, some ⟨bytes⟩)
    let fragment := reader.buffer.extract reader.cursor reader.buffer.size
    let pending := if reader.pending.isEmpty then fragment
      else reader.pending.fastAppend fragment
    reader := { reader with pending := pending, cursor := reader.buffer.size }
    if reader.ended then
      if reader.pending.isEmpty then return (reader, none)
      let bytes := reader.pending
      return ({ reader with pending := ByteArray.empty }, some ⟨bytes⟩)
    let chunk ← reader.handle.read reader.chunkSize
    reader := { reader with buffer := chunk, cursor := 0, ended := chunk.isEmpty }
  return (reader, none)

end Lutils
