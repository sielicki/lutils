/- Placeholder for the `tsort` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `tsort` is tracked in the README and awaits implementation. -/
def runTsort : Applet := unimplementedApplet

/-- Multicall registration for `tsort`. -/
abbrev TsortApplet := AppletTag "tsort" runTsort

end Lutils
