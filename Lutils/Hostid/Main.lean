/- Placeholder for the `hostid` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `hostid` is tracked in the README and awaits implementation. -/
def runHostid : Applet := unimplementedApplet

/-- Multicall registration for `hostid`. -/
abbrev HostidApplet := AppletTag "hostid" runHostid

end Lutils
