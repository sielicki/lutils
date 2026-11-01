/- Placeholder for the `arch` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `arch` is tracked in the README and awaits implementation. -/
def runArch : Applet := unimplementedApplet

/-- Multicall registration for `arch`. -/
abbrev ArchApplet := AppletTag "arch" runArch

end Lutils
