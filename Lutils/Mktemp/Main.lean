/- Placeholder for the `mktemp` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `mktemp` is tracked in the README and awaits implementation. -/
def runMktemp : Applet := unimplementedApplet

/-- Multicall registration for `mktemp`. -/
abbrev MktempApplet := AppletTag "mktemp" runMktemp

end Lutils
