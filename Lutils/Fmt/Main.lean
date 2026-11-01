/- Placeholder for the `fmt` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `fmt` is tracked in the README and awaits implementation. -/
def runFmt : Applet := unimplementedApplet

/-- Multicall registration for `fmt`. -/
abbrev FmtApplet := AppletTag "fmt" runFmt

end Lutils
