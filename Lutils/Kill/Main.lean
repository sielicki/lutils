/- Placeholder for the `kill` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `kill` is tracked in the README and awaits implementation. -/
def runKill : Applet := unimplementedApplet

/-- Multicall registration for `kill`. -/
abbrev KillApplet := AppletTag "kill" runKill

end Lutils
