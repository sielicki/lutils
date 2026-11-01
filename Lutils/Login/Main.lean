/- Placeholder for the `login` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `login` is tracked in the README and awaits implementation. -/
def runLogin : Applet := unimplementedApplet

/-- Multicall registration for `login`. -/
abbrev LoginApplet := AppletTag "login" runLogin

end Lutils
