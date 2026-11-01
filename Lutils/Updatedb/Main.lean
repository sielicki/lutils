/- Placeholder for the `updatedb` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `updatedb` is tracked in the README and awaits implementation. -/
def runUpdatedb : Applet := unimplementedApplet

/-- Multicall registration for `updatedb`. -/
abbrev UpdatedbApplet := AppletTag "updatedb" runUpdatedb

end Lutils
