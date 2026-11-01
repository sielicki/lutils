/- Placeholder for the `uname` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `uname` is tracked in the README and awaits implementation. -/
def runUname : Applet := unimplementedApplet

/-- Multicall registration for `uname`. -/
abbrev UnameApplet := AppletTag "uname" runUname

end Lutils
