/- Placeholder for the `who` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `who` is tracked in the README and awaits implementation. -/
def runWho : Applet := unimplementedApplet

/-- Multicall registration for `who`. -/
abbrev WhoApplet := AppletTag "who" runWho

end Lutils
