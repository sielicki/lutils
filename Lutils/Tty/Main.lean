/- Placeholder for the `tty` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `tty` is tracked in the README and awaits implementation. -/
def runTty : Applet := unimplementedApplet

/-- Multicall registration for `tty`. -/
abbrev TtyApplet := AppletTag "tty" runTty

end Lutils
