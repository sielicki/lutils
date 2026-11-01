/- Placeholder for the `id` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `id` is tracked in the README and awaits implementation. -/
def runId : Applet := unimplementedApplet

/-- Multicall registration for `id`. -/
abbrev IdApplet := AppletTag "id" runId

end Lutils
