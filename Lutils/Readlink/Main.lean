/- Placeholder for the `readlink` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `readlink` is tracked in the README and awaits implementation. -/
def runReadlink : Applet := unimplementedApplet

/-- Multicall registration for `readlink`. -/
abbrev ReadlinkApplet := AppletTag "readlink" runReadlink

end Lutils
