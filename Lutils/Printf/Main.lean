/- Placeholder for the `printf` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `printf` is tracked in the README and awaits implementation. -/
def runPrintf : Applet := unimplementedApplet

/-- Multicall registration for `printf`. -/
abbrev PrintfApplet := AppletTag "printf" runPrintf

end Lutils
