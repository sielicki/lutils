/- Placeholder for the `xargs` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `xargs` is tracked in the README and awaits implementation. -/
def runXargs : Applet := unimplementedApplet

/-- Multicall registration for `xargs`. -/
abbrev XargsApplet := AppletTag "xargs" runXargs

end Lutils
