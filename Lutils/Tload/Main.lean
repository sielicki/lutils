/- Placeholder for the `tload` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `tload` is tracked in the README and awaits implementation. -/
def runTload : Applet := unimplementedApplet

/-- Multicall registration for `tload`. -/
abbrev TloadApplet := AppletTag "tload" runTload

end Lutils
