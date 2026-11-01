/- Placeholder for the `factor` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `factor` is tracked in the README and awaits implementation. -/
def runFactor : Applet := unimplementedApplet

/-- Multicall registration for `factor`. -/
abbrev FactorApplet := AppletTag "factor" runFactor

end Lutils
