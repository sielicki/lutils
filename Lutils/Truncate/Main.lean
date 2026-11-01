/- Placeholder for the `truncate` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `truncate` is tracked in the README and awaits implementation. -/
def runTruncate : Applet := unimplementedApplet

/-- Multicall registration for `truncate`. -/
abbrev TruncateApplet := AppletTag "truncate" runTruncate

end Lutils
