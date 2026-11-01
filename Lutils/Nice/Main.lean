/- Placeholder for the `nice` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `nice` is tracked in the README and awaits implementation. -/
def runNice : Applet := unimplementedApplet

/-- Multicall registration for `nice`. -/
abbrev NiceApplet := AppletTag "nice" runNice

end Lutils
