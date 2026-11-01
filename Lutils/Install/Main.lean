/- Placeholder for the `install` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `install` is tracked in the README and awaits implementation. -/
def runInstall : Applet := unimplementedApplet

/-- Multicall registration for `install`. -/
abbrev InstallApplet := AppletTag "install" runInstall

end Lutils
