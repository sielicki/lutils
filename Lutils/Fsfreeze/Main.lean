/- Placeholder for the `fsfreeze` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `fsfreeze` is tracked in the README and awaits implementation. -/
def runFsfreeze : Applet := unimplementedApplet

/-- Multicall registration for `fsfreeze`. -/
abbrev FsfreezeApplet := AppletTag "fsfreeze" runFsfreeze

end Lutils
