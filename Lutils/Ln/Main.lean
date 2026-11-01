/- Placeholder for the `ln` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `ln` is tracked in the README and awaits implementation. -/
def runLn : Applet := unimplementedApplet

/-- Multicall registration for `ln`. -/
abbrev LnApplet := AppletTag "ln" runLn

end Lutils
