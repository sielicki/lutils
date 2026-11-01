/- Placeholder for the `nproc` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `nproc` is tracked in the README and awaits implementation. -/
def runNproc : Applet := unimplementedApplet

/-- Multicall registration for `nproc`. -/
abbrev NprocApplet := AppletTag "nproc" runNproc

end Lutils
