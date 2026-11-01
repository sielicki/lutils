/- Placeholder for the `lscpu` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `lscpu` is tracked in the README and awaits implementation. -/
def runLscpu : Applet := unimplementedApplet

/-- Multicall registration for `lscpu`. -/
abbrev LscpuApplet := AppletTag "lscpu" runLscpu

end Lutils
