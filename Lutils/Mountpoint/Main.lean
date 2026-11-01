/- Placeholder for the `mountpoint` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `mountpoint` is tracked in the README and awaits implementation. -/
def runMountpoint : Applet := unimplementedApplet

/-- Multicall registration for `mountpoint`. -/
abbrev MountpointApplet := AppletTag "mountpoint" runMountpoint

end Lutils
