/- Placeholder for the `nl` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `nl` is tracked in the README and awaits implementation. -/
def runNl : Applet := unimplementedApplet

/-- Multicall registration for `nl`. -/
abbrev NlApplet := AppletTag "nl" runNl

end Lutils
