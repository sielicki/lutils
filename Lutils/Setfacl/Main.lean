/- Placeholder for the `setfacl` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `setfacl` is tracked in the README and awaits implementation. -/
def runSetfacl : Applet := unimplementedApplet

/-- Multicall registration for `setfacl`. -/
abbrev SetfaclApplet := AppletTag "setfacl" runSetfacl

end Lutils
