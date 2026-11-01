/- Placeholder for the `df` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `df` is tracked in the README and awaits implementation. -/
def runDf : Applet := unimplementedApplet

/-- Multicall registration for `df`. -/
abbrev DfApplet := AppletTag "df" runDf

end Lutils
