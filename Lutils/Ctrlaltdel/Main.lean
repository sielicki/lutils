/- Placeholder for the `ctrlaltdel` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `ctrlaltdel` is tracked in the README and awaits implementation. -/
def runCtrlaltdel : Applet := unimplementedApplet

/-- Multicall registration for `ctrlaltdel`. -/
abbrev CtrlaltdelApplet := AppletTag "ctrlaltdel" runCtrlaltdel

end Lutils
