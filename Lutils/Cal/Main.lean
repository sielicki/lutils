/- Placeholder for the `cal` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `cal` is tracked in the README and awaits implementation. -/
def runCal : Applet := unimplementedApplet

/-- Multicall registration for `cal`. -/
abbrev CalApplet := AppletTag "cal" runCal

end Lutils
