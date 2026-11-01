/- Placeholder for the `nologin` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `nologin` is tracked in the README and awaits implementation. -/
def runNologin : Applet := unimplementedApplet

/-- Multicall registration for `nologin`. -/
abbrev NologinApplet := AppletTag "nologin" runNologin

end Lutils
