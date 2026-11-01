/- Placeholder for the `pkill` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `pkill` is tracked in the README and awaits implementation. -/
def runPkill : Applet := unimplementedApplet

/-- Multicall registration for `pkill`. -/
abbrev PkillApplet := AppletTag "pkill" runPkill

end Lutils
