/- True utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- `true`: do nothing, successfully. -/
def runTrue : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "true" args then return code
  return exitOk

/-- Multicall registration for `true`. -/
abbrev TrueApplet := AppletTag "true" runTrue

end Lutils
