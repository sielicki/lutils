/- Placeholder for the `ptx` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `ptx` is tracked in the README and awaits implementation. -/
def runPtx : Applet := unimplementedApplet

/-- Multicall registration for `ptx`. -/
abbrev PtxApplet := AppletTag "ptx" runPtx

end Lutils
