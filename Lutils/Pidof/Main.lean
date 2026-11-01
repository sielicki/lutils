/- Placeholder for the `pidof` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `pidof` is tracked in the README and awaits implementation. -/
def runPidof : Applet := unimplementedApplet

/-- Multicall registration for `pidof`. -/
abbrev PidofApplet := AppletTag "pidof" runPidof

end Lutils
