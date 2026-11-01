/- Placeholder for the `diff` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `diff` is tracked in the README and awaits implementation. -/
def runDiff : Applet := unimplementedApplet

/-- Multicall registration for `diff`. -/
abbrev DiffApplet := AppletTag "diff" runDiff

end Lutils
