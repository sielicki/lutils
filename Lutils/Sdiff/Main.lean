/- Placeholder for the `sdiff` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `sdiff` is tracked in the README and awaits implementation. -/
def runSdiff : Applet := unimplementedApplet

/-- Multicall registration for `sdiff`. -/
abbrev SdiffApplet := AppletTag "sdiff" runSdiff

end Lutils
