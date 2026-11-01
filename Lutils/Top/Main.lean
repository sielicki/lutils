/- Placeholder for the `top` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `top` is tracked in the README and awaits implementation. -/
def runTop : Applet := unimplementedApplet

/-- Multicall registration for `top`. -/
abbrev TopApplet := AppletTag "top" runTop

end Lutils
