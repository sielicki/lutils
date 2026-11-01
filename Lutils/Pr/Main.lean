/- Placeholder for the `pr` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `pr` is tracked in the README and awaits implementation. -/
def runPr : Applet := unimplementedApplet

/-- Multicall registration for `pr`. -/
abbrev PrApplet := AppletTag "pr" runPr

end Lutils
