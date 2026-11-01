/- Placeholder for the `su` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `su` is tracked in the README and awaits implementation. -/
def runSu : Applet := unimplementedApplet

/-- Multicall registration for `su`. -/
abbrev SuApplet := AppletTag "su" runSu

end Lutils
