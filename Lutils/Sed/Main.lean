/- Placeholder for the `sed` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `sed` is tracked in the README and awaits implementation. -/
def runSed : Applet := unimplementedApplet

/-- Multicall registration for `sed`. -/
abbrev SedApplet := AppletTag "sed" runSed

end Lutils
