/- Placeholder for the `ps` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `ps` is tracked in the README and awaits implementation. -/
def runPs : Applet := unimplementedApplet

/-- Multicall registration for `ps`. -/
abbrev PsApplet := AppletTag "ps" runPs

end Lutils
