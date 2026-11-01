/- Placeholder for the `hostname` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `hostname` is tracked in the README and awaits implementation. -/
def runHostname : Applet := unimplementedApplet

/-- Multicall registration for `hostname`. -/
abbrev HostnameApplet := AppletTag "hostname" runHostname

end Lutils
