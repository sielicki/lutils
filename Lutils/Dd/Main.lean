/- Placeholder for the `dd` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `dd` is tracked in the README and awaits implementation. -/
def runDd : Applet := unimplementedApplet

/-- Multicall registration for `dd`. -/
abbrev DdApplet := AppletTag "dd" runDd

end Lutils
