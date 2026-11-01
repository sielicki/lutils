/- Placeholder for the `chown` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `chown` is tracked in the README and awaits implementation. -/
def runChown : Applet := unimplementedApplet

/-- Multicall registration for `chown`. -/
abbrev ChownApplet := AppletTag "chown" runChown

end Lutils
