/- Placeholder for the `last` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `last` is tracked in the README and awaits implementation. -/
def runLast : Applet := unimplementedApplet

/-- Multicall registration for `last`. -/
abbrev LastApplet := AppletTag "last" runLast

end Lutils
