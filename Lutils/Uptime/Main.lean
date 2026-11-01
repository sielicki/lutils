/- Placeholder for the `uptime` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `uptime` is tracked in the README and awaits implementation. -/
def runUptime : Applet := unimplementedApplet

/-- Multicall registration for `uptime`. -/
abbrev UptimeApplet := AppletTag "uptime" runUptime

end Lutils
