/- False utility implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- `false`: do nothing, unsuccessfully. -/
def runFalse : Applet := fun prog args => do
  if let some code ← handleMetaFlags prog "false" args then return code
  return exitFail

end Lutils
