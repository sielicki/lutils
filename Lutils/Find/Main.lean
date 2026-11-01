/- Placeholder for the `find` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `find` is tracked in the README and awaits implementation. -/
def runFind : Applet := unimplementedApplet

/-- Multicall registration for `find`. -/
abbrev FindApplet := AppletTag "find" runFind

end Lutils
