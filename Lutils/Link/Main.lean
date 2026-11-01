/- Placeholder for the `link` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `link` is tracked in the README and awaits implementation. -/
def runLink : Applet := unimplementedApplet

/-- Multicall registration for `link`. -/
abbrev LinkApplet := AppletTag "link" runLink

end Lutils
