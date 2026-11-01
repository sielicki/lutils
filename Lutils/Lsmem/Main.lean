/- Placeholder for the `lsmem` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `lsmem` is tracked in the README and awaits implementation. -/
def runLsmem : Applet := unimplementedApplet

/-- Multicall registration for `lsmem`. -/
abbrev LsmemApplet := AppletTag "lsmem" runLsmem

end Lutils
