import Lutils.Shared.BaseEncoding

namespace Lutils.BaseCommand

open BaseEncoding

structure Options where
  format : Option Format := none
  decode : Bool := false
  ignoreGarbage : Bool := false
  wrapColumns : Nat := 76
  files : List String := []

private def formatOf : String → Option Format
  | "--base64" => some (.power .base64)
  | "--base64url" => some (.power .base64url)
  | "--base32" => some (.power .base32)
  | "--base32hex" => some (.power .base32hex)
  | "--base16" => some (.power .base16)
  | "--base2msbf" => some (.power .base2msbf)
  | "--base2lsbf" => some (.power .base2lsbf)
  | "--base58" => some .base58
  | "--z85" => some .z85
  | _ => none

private def parseColumns (prog value : String) : IO (Option Nat) := do
  match value.toNat? with
  | some n => return some n
  | none =>
    reportError prog s!"invalid wrap size: '{value}'"
    return none

private def expandShort (arg : String) : List String :=
  if arg.startsWith "-" && !arg.startsWith "--" && arg.length > 2 &&
      (arg.drop 1).toString.toList.all (fun c => "di".contains c) then
    (arg.drop 1).toString.toList.map (fun c => "-" ++ String.singleton c)
  else [arg]

private def parse (prog : String) (initial : Option Format) :
    List String → IO (Option Options) := fun args =>
  let (before, after) := args.span (· != "--")
  go { format := initial } false (before.flatMap expandShort ++ after)
where
  go (opts : Options) (literal : Bool) : List String → IO (Option Options)
    | [] => return some opts
    | arg :: rest => do
      if literal then go { opts with files := opts.files ++ [arg] } true rest
      else if arg == "--" then go opts true rest
      else if arg == "-d" || arg == "--decode" then go { opts with decode := true } false rest
      else if arg == "-i" || arg == "--ignore-garbage" then go { opts with ignoreGarbage := true } false rest
      else if arg == "-w" || arg == "--wrap" then
        match rest with
        | value :: tail =>
          let some columns ← parseColumns prog value | return none
          go { opts with wrapColumns := columns } false tail
        | [] => reportError prog s!"option '{arg}' requires an argument"; return none
      else if arg.startsWith "--wrap=" then
        let some columns ← parseColumns prog ((arg.drop 7).toString) | return none
        go { opts with wrapColumns := columns } false rest
      else if arg.startsWith "-w" && arg.length > 2 then
        let some columns ← parseColumns prog ((arg.drop 2).toString) | return none
        go { opts with wrapColumns := columns } false rest
      else if let some format := formatOf arg then
        go { opts with format := some format } false rest
      else if arg.startsWith "-" && arg != "-" then
        reportError prog s!"unrecognized option '{arg}'"
        IO.eprintln s!"Try '{prog} --help' for more information."
        return none
      else go { opts with files := opts.files ++ [arg] } false rest

/-- Keep the file and terminal handles at the boundary of the pure encoder. -/
private def encodePowerStream (codec : Codec) (columns : Nat) (file : String) : IO Unit := do
  let transducer : ByteStreamTransducer (EncodeStreamState codec columns) Unit :=
    { initial := EncodeStreamState.empty codec columns
      step := encodeStreamChunk codec columns
      finish := fun state => (finishEncodeStream codec columns state, ()) }
  runByteStream file ByteChunkSize.fourMiB transducer

private def decodePowerStream (codec : Codec) (ignoreGarbage : Bool)
    (file : String) : IO Bool := do
  let transducer : ByteStreamTransducer (DecodeStreamState codec) Bool :=
    { initial := .fast (FastDecodeWindow.empty codec)
      step := decodeStreamChunk codec ignoreGarbage
      finish := fun state =>
        let result := finishDecodeStream codec ignoreGarbage state
        (result.bytes, result.valid) }
  runByteStream file ByteChunkSize.fourMiB transducer

private def decodeFormatStream (format : Format) (ignoreGarbage : Bool)
    (file : String) : IO Bool :=
  match format with
  | .power codec => decodePowerStream codec ignoreGarbage file
  | .base58 =>
    let transducer : ByteStreamTransducer Base58DecodeState Bool :=
      { initial := {}
        step := base58DecodeChunk ignoreGarbage
        finish := fun state =>
          let result := finishBase58Decode state
          (result.bytes, result.valid) }
    runByteStream file ByteChunkSize.fourMiB transducer
  | .z85 =>
    let transducer : ByteStreamTransducer Z85DecodeState Bool :=
      { initial := {}
        step := z85DecodeChunk ignoreGarbage
        finish := fun state => (ByteArray.empty, finishZ85Decode state) }
    runByteStream file ByteChunkSize.fourMiB transducer

/-- Run an RFC 4648 encoder/decoder or the corresponding `basenc` format. -/
def run (initial : Option Format) (prog : String) (args : List String) : IO UInt32 := do
  if let some code ← handleMetaFlags prog s!"{prog} [OPTION]... [FILE]" args then return code
  let some opts ← parse prog initial args | return exitFail
  let some format := opts.format | do
    reportError prog "missing encoding type"
    IO.eprintln s!"Try '{prog} --help' for more information."
    return exitFail
  let file ← match opts.files with
    | [] => pure "-"
    | [file] => pure file
    | _ =>
      reportError prog "extra operand"
      IO.eprintln s!"Try '{prog} --help' for more information."
      return exitFail
  if !opts.decode then
    if let .power codec := format then
      try
        encodePowerStream codec opts.wrapColumns file
        return exitOk
      catch e =>
        reportFileError prog file e
        return exitFail
  else
    let valid ← try decodeFormatStream format opts.ignoreGarbage file catch e =>
      reportFileError prog file e
      return exitFail
    if valid then return exitOk
    reportError prog "invalid input"
    return exitFail
  let input ← try readOperandBytes file catch e =>
    reportFileError prog file e
    return exitFail
  let some output := encodeFormat format input | do
    reportError prog "invalid input (length must be multiple of 4 characters)"
    return exitFail
  writeStdout (wrap output opts.wrapColumns)
  return exitOk

end Lutils.BaseCommand
