/- Placeholder for the `whoami` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `whoami` is tracked in the README and awaits implementation. -/
def runWhoami : Applet := unimplementedApplet

/-- Multicall registration for `whoami`. -/
abbrev WhoamiApplet := AppletTag "whoami" runWhoami

end Lutils
