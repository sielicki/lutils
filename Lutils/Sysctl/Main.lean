/- Placeholder for the `sysctl` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `sysctl` is tracked in the README and awaits implementation. -/
def runSysctl : Applet := unimplementedApplet

/-- Multicall registration for `sysctl`. -/
abbrev SysctlApplet := AppletTag "sysctl" runSysctl

end Lutils
