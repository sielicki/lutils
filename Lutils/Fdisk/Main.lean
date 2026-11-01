/- Placeholder for the `fdisk` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `fdisk` is tracked in the README and awaits implementation. -/
def runFdisk : Applet := unimplementedApplet

/-- Multicall registration for `fdisk`. -/
abbrev FdiskApplet := AppletTag "fdisk" runFdisk

end Lutils
