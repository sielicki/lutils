/- Placeholder for the `free` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `free` is tracked in the README and awaits implementation. -/
def runFree : Applet := unimplementedApplet

/-- Multicall registration for `free`. -/
abbrev FreeApplet := AppletTag "free" runFree

end Lutils
