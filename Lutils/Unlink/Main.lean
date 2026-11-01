/- Placeholder for the `unlink` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `unlink` is tracked in the README and awaits implementation. -/
def runUnlink : Applet := unimplementedApplet

/-- Multicall registration for `unlink`. -/
abbrev UnlinkApplet := AppletTag "unlink" runUnlink

end Lutils
