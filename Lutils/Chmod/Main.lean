/- Placeholder for the `chmod` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `chmod` is tracked in the README and awaits implementation. -/
def runChmod : Applet := unimplementedApplet

/-- Multicall registration for `chmod`. -/
abbrev ChmodApplet := AppletTag "chmod" runChmod

end Lutils
