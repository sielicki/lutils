/- Placeholder for the `pathchk` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `pathchk` is tracked in the README and awaits implementation. -/
def runPathchk : Applet := unimplementedApplet

/-- Multicall registration for `pathchk`. -/
abbrev PathchkApplet := AppletTag "pathchk" runPathchk

end Lutils
