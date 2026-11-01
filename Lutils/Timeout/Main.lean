/- Placeholder for the `timeout` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `timeout` is tracked in the README and awaits implementation. -/
def runTimeout : Applet := unimplementedApplet

/-- Multicall registration for `timeout`. -/
abbrev TimeoutApplet := AppletTag "timeout" runTimeout

end Lutils
