/- Placeholder for the `setsid` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `setsid` is tracked in the README and awaits implementation. -/
def runSetsid : Applet := unimplementedApplet

/-- Multicall registration for `setsid`. -/
abbrev SetsidApplet := AppletTag "setsid" runSetsid

end Lutils
