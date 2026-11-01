/- Placeholder for the `sync` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `sync` is tracked in the README and awaits implementation. -/
def runSync : Applet := unimplementedApplet

/-- Multicall registration for `sync`. -/
abbrev SyncApplet := AppletTag "sync" runSync

end Lutils
