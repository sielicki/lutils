/- Placeholder for the `blockdev` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `blockdev` is tracked in the README and awaits implementation. -/
def runBlockdev : Applet := unimplementedApplet

/-- Multicall registration for `blockdev`. -/
abbrev BlockdevApplet := AppletTag "blockdev" runBlockdev

end Lutils
