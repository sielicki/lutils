/- Placeholder for the `mesg` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `mesg` is tracked in the README and awaits implementation. -/
def runMesg : Applet := unimplementedApplet

/-- Multicall registration for `mesg`. -/
abbrev MesgApplet := AppletTag "mesg" runMesg

end Lutils
