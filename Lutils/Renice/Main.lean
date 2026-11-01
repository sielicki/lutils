/- Placeholder for the `renice` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `renice` is tracked in the README and awaits implementation. -/
def runRenice : Applet := unimplementedApplet

/-- Multicall registration for `renice`. -/
abbrev ReniceApplet := AppletTag "renice" runRenice

end Lutils
