/- Shared path operations. -/
import Lutils.Shared.Common

namespace Lutils

/-- Strip trailing slashes, keeping a lone root `/` intact. -/
def stripTrailingSlashes (s : String) : String :=
  if s.isEmpty then s
  else
    let trimmed := s.dropEndWhile '/'
    if trimmed.isEmpty then "/" else trimmed.copy

/-- The final path component per GNU `basename`. -/
def baseNameOf (path : String) : String :=
  if path.isEmpty then ""
  else
    let trimmed := path.dropEndWhile '/'
    if trimmed.isEmpty then "/"
    else (trimmed.takeEndWhile (· != '/')).copy

/-- Except for the preserved root, stripping removes every trailing slash. -/
theorem stripTrailingSlashes_normalized (s : String) :
    stripTrailingSlashes s = "/" ∨ (stripTrailingSlashes s).endsWith '/' = false := by
  by_cases hs : s.isEmpty = true
  · right
    have hempty : s = "" := String.isEmpty_iff.mp hs
    simpa [hempty, stripTrailingSlashes] using
      (show "".endsWith '/' = false by decide)
  · simp only [stripTrailingSlashes, hs, Bool.false_eq_true, ↓reduceIte]
    by_cases ht : (s.dropEndWhile '/').isEmpty = true
    · left
      simp [ht]
    · right
      simp [ht, String.Slice.endsWith_copy]

/-- Applying the slash normalization a second time cannot change the path. -/
theorem stripTrailingSlashes_idempotent (s : String) :
    stripTrailingSlashes (stripTrailingSlashes s) = stripTrailingSlashes s := by
  rcases stripTrailingSlashes_normalized s with hroot | hnormal
  · rw [hroot]
    have hslash : "/".revAll '/' = true := by
      rw [String.revAll_eq_revAll_toSlice, String.Slice.revAll_char_iff]
      decide
    simp [stripTrailingSlashes, hslash]
  · let t := stripTrailingSlashes s
    change stripTrailingSlashes t = t
    by_cases ht : t.isEmpty = true
    · have hempty : t = "" := String.isEmpty_iff.mp ht
      simp [hempty, stripTrailingSlashes]
    · have hdrop : t.dropEndWhile '/' = t.toSlice :=
        String.dropEndWhile_eq_toSlice hnormal
      simp [stripTrailingSlashes, ht, hdrop]

/-- A basename is either root or a single component, with no slash inside it. -/
theorem baseNameOf_singleComponent (path : String) :
    baseNameOf path = "/" ∨ (baseNameOf path).toList.all (· != '/') = true := by
  by_cases hp : path.isEmpty = true
  · right
    simp [baseNameOf, hp]
  · simp only [baseNameOf, hp, Bool.false_eq_true, ↓reduceIte]
    let trimmed := path.dropEndWhile '/'
    by_cases ht : trimmed.isEmpty = true
    · left
      simp [trimmed, ht]
    · right
      simp [trimmed, ht, ← String.revAll_bool_eq, String.Slice.revAll_copy]

end Lutils
