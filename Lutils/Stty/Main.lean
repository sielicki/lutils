/- Placeholder for the `stty` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `stty` is tracked in the README and awaits implementation. -/
def runStty : Applet := unimplementedApplet

/-- Multicall registration for `stty`. -/
abbrev SttyApplet := AppletTag "stty" runStty

end Lutils
