/- Placeholder for the `stat` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `stat` is tracked in the README and awaits implementation. -/
def runStat : Applet := unimplementedApplet

/-- Multicall registration for `stat`. -/
abbrev StatApplet := AppletTag "stat" runStat

end Lutils
