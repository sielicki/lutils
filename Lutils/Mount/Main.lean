/- Placeholder for the `mount` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `mount` is tracked in the README and awaits implementation. -/
def runMount : Applet := unimplementedApplet

/-- Multicall registration for `mount`. -/
abbrev MountApplet := AppletTag "mount" runMount

end Lutils
