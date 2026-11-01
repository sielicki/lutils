/- Placeholder for the `vdir` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `vdir` is tracked in the README and awaits implementation. -/
def runVdir : Applet := unimplementedApplet

/-- Multicall registration for `vdir`. -/
abbrev VdirApplet := AppletTag "vdir" runVdir

end Lutils
