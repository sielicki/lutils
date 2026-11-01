/- Shared placeholder for tracked utilities awaiting an implementation. -/
import Lutils.Shared.Common

namespace Lutils

/-- A callable placeholder for a tracked utility awaiting implementation. -/
def unimplementedApplet : Applet := fun prog _args => do
  reportError prog "not yet implemented"
  return exitFail

end Lutils
