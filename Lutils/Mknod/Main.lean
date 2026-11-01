/- Placeholder for the `mknod` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `mknod` is tracked in the README and awaits implementation. -/
def runMknod : Applet := unimplementedApplet

/-- Multicall registration for `mknod`. -/
abbrev MknodApplet := AppletTag "mknod" runMknod

end Lutils
