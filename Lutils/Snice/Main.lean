/- Placeholder for the `snice` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `snice` is tracked in the README and awaits implementation. -/
def runSnice : Applet := unimplementedApplet

/-- Multicall registration for `snice`. -/
abbrev SniceApplet := AppletTag "snice" runSnice

end Lutils
