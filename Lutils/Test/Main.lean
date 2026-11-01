/- Placeholder for the `test` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `test` is tracked in the README and awaits implementation. -/
def runTest : Applet := unimplementedApplet

/-- Multicall registration for `test`. -/
abbrev TestApplet := AppletTag "test" runTest

end Lutils
