/- Placeholder for the `du` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `du` is tracked in the README and awaits implementation. -/
def runDu : Applet := unimplementedApplet

/-- Multicall registration for `du`. -/
abbrev DuApplet := AppletTag "du" runDu

end Lutils
