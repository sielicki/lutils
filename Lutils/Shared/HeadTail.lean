/- Shared head/tail support. -/
import Lutils.Shared.Common

namespace Lutils

inductive HeadTailKind where
  | head
  | tail
  deriving BEq

/-- Multiply-by-suffix used by `head`/`tail` counts.
GNU suffixes: `b` = 512, `K`/`KiB` = 1024, `KB` = 1000, and so on. -/
def sizeSuffixMultiplier (suffix : String) : Option Nat :=
  match suffix with
  | "" => some 1
  | "b" => some 512
  | "K" | "KiB" | "k" | "kB" => some 1024
  | "KB" => some 1000
  | "M" | "MiB" | "m" => some (1024 * 1024)
  | "MB" => some (1000 * 1000)
  | "G" | "GiB" | "g" => some (1024 * 1024 * 1024)
  | "GB" => some (1000 * 1000 * 1000)
  | "T" | "TiB" | "t" => some (1024 * 1024 * 1024 * 1024)
  | "TB" => some (1000 * 1000 * 1000 * 1000)
  | _ => none

/-- The three distinct forms of a `head`/`tail` count. -/
inductive SliceCount where
  | plain (value : Nat)
  | negative (value : Nat)
  | plus (value : Nat)

/-- Parse a `head`/`tail`-style count such as `10`, `+3`, `-5`, or `2K`. -/
def parseCount (prog usage valueDesc : String) (s : String) :
    IO (Except UInt32 SliceCount) := do
  let rest :=
    if s.startsWith "+" || s.startsWith "-" then String.ofList (s.toList.drop 1)
    else s
  let digits := String.ofList (rest.toList.takeWhile (·.isDigit))
  let suffix := String.ofList (rest.toList.dropWhile (·.isDigit))
  match digits.toNat?, sizeSuffixMultiplier suffix with
  | some n, some mult =>
      let value := n * mult
      return .ok (if s.startsWith "+" then .plus value
                  else if s.startsWith "-" then .negative value
                  else .plain value)
  | _, _ =>
      reportError prog s!"invalid {valueDesc}: '{s}'"
      IO.eprintln s!"Usage: {usage}"
      return .error exitFail

/-- The last count option determines the unit used by `head` or `tail`. -/
inductive HeadTailMode where
  | lines (count : SliceCount)
  | bytes (count : SliceCount)

/-- Parse the obsolete `head -NUM[bck]` byte-count syntax. -/
def obsoleteHeadByteCount? (arg : String) : Option Nat := do
  match arg.toList with
  | '-' :: rest =>
      let (digits, suffix) := rest.span Char.isDigit
      if digits.isEmpty then none
      else
        let count ← (String.ofList digits).toNat?
        let multiplier ← match suffix with
          | ['b'] => some 512
          | ['k'] => some 1024
          | ['c'] => some 1
          | _ => none
        some (count * multiplier)
  | _ => none

/-- Options shared by `head` and `tail`. -/
structure HeadTailOpts where
  mode : HeadTailMode := .lines (.plain 10)
  quiet : Bool := false
  verbose : Bool := false
  zeroTerminated : Bool := false
  files : List String := []

/-- Parse `head`/`tail` arguments. Supports `-n NUM`, `-c NUM`, the combined
`-nNUM` forms, long options, and the obsolete `-NUM` line count. -/
def parseHeadTail (kind : HeadTailKind) (prog : String) (args : List String) :
    IO (Except UInt32 HeadTailOpts) := do
  let usage := s!"{prog} [OPTION]... [FILE]..."
  let mut opts : HeadTailOpts := {}
  let mut filesRev : List String := []
  let arr := args.toArray
  let mut i := 0
  let mut stopOpts := false
  while i < arr.size do
    let some a := arr[i]? | break
    i := i + 1
    let obsoleteByteCount := if kind == .head then obsoleteHeadByteCount? a else none
    if stopOpts then
      filesRev := a :: filesRev
    else if a == "--" then
      stopOpts := true
    else if a == "-q" || a == "--quiet" || a == "--silent" then
      opts := { opts with quiet := true, verbose := false }
    else if a == "-v" || a == "--verbose" then
      opts := { opts with verbose := true, quiet := false }
    else if a == "-z" || a == "--zero-terminated" then
      opts := { opts with zeroTerminated := true }
    else if a == "-n" || a == "--lines" then
      let some value := arr[i]? | do
        reportError prog s!"option requires an argument -- 'n'"
        return .error exitFail
      match ← parseCount prog usage "number of lines" value with
      | .error code => return .error code
      | .ok count => opts := { opts with mode := .lines count }
      i := i + 1
    else if a.startsWith "--lines=" then
      let v := String.ofList (a.toList.drop "--lines=".length)
      match ← parseCount prog usage "number of lines" v with
      | .error code => return .error code
      | .ok count => opts := { opts with mode := .lines count }
    else if a.startsWith "-n" && a.length > 2 then
      let v := String.ofList (a.toList.drop 2)
      match ← parseCount prog usage "number of lines" v with
      | .error code => return .error code
      | .ok count => opts := { opts with mode := .lines count }
    else if a == "-c" || a == "--bytes" then
      let some value := arr[i]? | do
        reportError prog s!"option requires an argument -- 'c'"
        return .error exitFail
      match ← parseCount prog usage "number of bytes" value with
      | .error code => return .error code
      | .ok count => opts := { opts with mode := .bytes count }
      i := i + 1
    else if a.startsWith "--bytes=" then
      let v := String.ofList (a.toList.drop "--bytes=".length)
      match ← parseCount prog usage "number of bytes" v with
      | .error code => return .error code
      | .ok count => opts := { opts with mode := .bytes count }
    else if a.startsWith "-c" && a.length > 2 then
      let v := String.ofList (a.toList.drop 2)
      match ← parseCount prog usage "number of bytes" v with
      | .error code => return .error code
      | .ok count => opts := { opts with mode := .bytes count }
    else if a == "-f" || a == "--follow" then
      reportError prog "option -f/--follow is not supported yet"
      return .error exitFail
    else if let some count := obsoleteByteCount then
      opts := { opts with mode := .bytes (.plain count) }
    else if a.startsWith "-" && a.length > 1 && a != "-" &&
        (a.toList.drop 1).all (·.isDigit) then
      -- Obsolete `head -5` form.
      match (String.ofList (a.toList.drop 1)).toNat? with
      | some n => opts := { opts with mode := .lines (.plain n) }
      | none =>
          reportError prog s!"invalid option -- '{a}'"
          return .error exitFail
    else if a.startsWith "-" && a.length > 1 && a != "-" then
      reportError prog s!"invalid option -- '{a}'"
      IO.eprintln s!"Usage: {usage}"
      return .error exitFail
    else
      filesRev := a :: filesRev
  opts := { opts with files := filesRev.reverse }
  return .ok opts

/-- The first `n` delimiter-terminated lines, or all bytes if fewer occur. -/
def headLinePrefix (data : ByteArray) (delimiter : UInt8) (n : Nat) : ByteArray := Id.run do
  if n == 0 then return ByteArray.empty
  let mut seen := 0
  for h : i in [:data.size] do
    if data[i] == delimiter then
      seen := seen + 1
      if seen == n then
        return data.extract 0 (i + 1)
  return data

/-- The last `n` lines, scanning backward without storing every line end. -/
def tailLineSuffix (data : ByteArray) (delimiter : UInt8) (n : Nat) : ByteArray := Id.run do
  if n == 0 then return ByteArray.empty
  let mut seen := 0
  for h : i in [:data.size] do
    let j := data.size - (i + 1)
    have hj : j < data.size := by
      have hi : i < data.size := h.upper
      omega
    -- The final delimiter closes the final line; it is not an extra line.
    if j + 1 != data.size && data[j] == delimiter then
      seen := seen + 1
      if seen == n then
        return data.extract (j + 1) data.size
  return data

/-- Select a head or tail slice of `data` per `opts`. -/
def sliceHeadTail (kind : HeadTailKind) (opts : HeadTailOpts) (data : ByteArray) : ByteArray := Id.run do
  match opts.mode with
  | .bytes count =>
      let size := data.size
      if kind == .head then
        match count with
        | .plain n | .plus n => data.extract 0 (min size n)
        | .negative n => data.extract 0 (size - min size n)
      else
        match count with
        | .plus n => data.extract (min size (n - 1)) size
        | .plain n | .negative n => data.extract (size - min size n) size
  | .lines count =>
      let delimiter : UInt8 := if opts.zeroTerminated then 0 else 10
      match kind, count with
      | .head, .plain n | .head, .plus n =>
          return headLinePrefix data delimiter n
      | .tail, .plain n | .tail, .negative n =>
          return tailLineSuffix data delimiter n
      | _, _ => pure ()
      let mut ends : Array Nat := #[]
      -- The loop binder supplies `i < data.size`, so reading each byte needs
      -- neither an Option allocation nor a bounds check.
      for h : i in [:data.size] do
        if data[i] == delimiter then
          ends := ends.push (i + 1)
      if data.size > 0 && ends.back? != some data.size then
        ends := ends.push data.size
      let total := ends.size
      let boundary (n : Nat) : Nat :=
        if n == 0 then 0 else (ends[n - 1]?).getD data.size
      if kind == .head then
        let selected := match count with
          | .plain n | .plus n => min total n
          | .negative n => total - min total n
        data.extract 0 (boundary selected)
      else
        let selected := match count with
          | .plus n => min total (n - 1)
          | .plain n | .negative n => total - min total n
        data.extract (boundary selected) data.size

def runHeadTail (kind : HeadTailKind) : Applet := fun prog args => do
  let usage := s!"{prog} [OPTION]... [FILE]..."
  if let some code ← handleMetaFlags prog usage args then return code
  match ← parseHeadTail kind prog args with
  | .error code => return code
  | .ok opts =>
      let files := operandsOrStdin opts.files
      let showHeaders := opts.verbose || (files.length > 1 && !opts.quiet)
      let mut status := exitOk
      let mut first := true
      for file in files do
        try
          let data ← readOperandBytes file
          if showHeaders then
            if !first then putStr "\n"
            let name := if file == "-" then "standard input" else file
            putStr s!"==> {name} <==\n"
          first := false
          writeStdout (sliceHeadTail kind opts data)
        catch e =>
          if isBrokenPipe e then
            return exitOk
          reportFileError prog file e
          status := exitFail
      return status

end Lutils
