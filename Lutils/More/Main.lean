/- Placeholder for the `more` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `more` is tracked in the README and awaits implementation. -/
def runMore : Applet := unimplementedApplet

/-- Multicall registration for `more`. -/
abbrev MoreApplet := AppletTag "more" runMore

end Lutils
