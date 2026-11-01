/- Placeholder for the `locate` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `locate` is tracked in the README and awaits implementation. -/
def runLocate : Applet := unimplementedApplet

/-- Multicall registration for `locate`. -/
abbrev LocateApplet := AppletTag "locate" runLocate

end Lutils
