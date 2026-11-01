/- Placeholder for the `chcpu` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `chcpu` is tracked in the README and awaits implementation. -/
def runChcpu : Applet := unimplementedApplet

/-- Multicall registration for `chcpu`. -/
abbrev ChcpuApplet := AppletTag "chcpu" runChcpu

end Lutils
