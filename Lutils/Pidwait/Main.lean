/- Placeholder for the `pidwait` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `pidwait` is tracked in the README and awaits implementation. -/
def runPidwait : Applet := unimplementedApplet

/-- Multicall registration for `pidwait`. -/
abbrev PidwaitApplet := AppletTag "pidwait" runPidwait

end Lutils
