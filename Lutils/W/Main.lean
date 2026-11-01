/- Placeholder for the `w` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `w` is tracked in the README and awaits implementation. -/
def runW : Applet := unimplementedApplet

/-- Multicall registration for `w`. -/
abbrev WApplet := AppletTag "w" runW

end Lutils
