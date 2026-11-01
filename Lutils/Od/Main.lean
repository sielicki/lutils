/- Placeholder for the `od` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `od` is tracked in the README and awaits implementation. -/
def runOd : Applet := unimplementedApplet

/-- Multicall registration for `od`. -/
abbrev OdApplet := AppletTag "od" runOd

end Lutils
