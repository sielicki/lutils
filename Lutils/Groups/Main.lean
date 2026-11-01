/- Placeholder for the `groups` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `groups` is tracked in the README and awaits implementation. -/
def runGroups : Applet := unimplementedApplet

/-- Multicall registration for `groups`. -/
abbrev GroupsApplet := AppletTag "groups" runGroups

end Lutils
