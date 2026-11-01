/- Placeholder for the `lsblk` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `lsblk` is tracked in the README and awaits implementation. -/
def runLsblk : Applet := unimplementedApplet

/-- Multicall registration for `lsblk`. -/
abbrev LsblkApplet := AppletTag "lsblk" runLsblk

end Lutils
