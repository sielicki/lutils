/- Placeholder for the `stdbuf` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `stdbuf` is tracked in the README and awaits implementation. -/
def runStdbuf : Applet := unimplementedApplet

/-- Multicall registration for `stdbuf`. -/
abbrev StdbufApplet := AppletTag "stdbuf" runStdbuf

end Lutils
