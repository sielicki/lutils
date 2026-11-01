/- Placeholder for the `shuf` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `shuf` is tracked in the README and awaits implementation. -/
def runShuf : Applet := unimplementedApplet

/-- Multicall registration for `shuf`. -/
abbrev ShufApplet := AppletTag "shuf" runShuf

end Lutils
