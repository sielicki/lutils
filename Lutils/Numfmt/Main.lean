/- Placeholder for the `numfmt` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `numfmt` is tracked in the README and awaits implementation. -/
def runNumfmt : Applet := unimplementedApplet

/-- Multicall registration for `numfmt`. -/
abbrev NumfmtApplet := AppletTag "numfmt" runNumfmt

end Lutils
