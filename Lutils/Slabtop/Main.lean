/- Placeholder for the `slabtop` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `slabtop` is tracked in the README and awaits implementation. -/
def runSlabtop : Applet := unimplementedApplet

/-- Multicall registration for `slabtop`. -/
abbrev SlabtopApplet := AppletTag "slabtop" runSlabtop

end Lutils
