/- Placeholder for the `users` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `users` is tracked in the README and awaits implementation. -/
def runUsers : Applet := unimplementedApplet

/-- Multicall registration for `users`. -/
abbrev UsersApplet := AppletTag "users" runUsers

end Lutils
