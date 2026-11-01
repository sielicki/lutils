/- Placeholder for the `lsns` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `lsns` is tracked in the README and awaits implementation. -/
def runLsns : Applet := unimplementedApplet

/-- Multicall registration for `lsns`. -/
abbrev LsnsApplet := AppletTag "lsns" runLsns

end Lutils
