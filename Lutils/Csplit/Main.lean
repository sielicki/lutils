/- Placeholder for the `csplit` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `csplit` is tracked in the README and awaits implementation. -/
def runCsplit : Applet := unimplementedApplet

/-- Multicall registration for `csplit`. -/
abbrev CsplitApplet := AppletTag "csplit" runCsplit

end Lutils
