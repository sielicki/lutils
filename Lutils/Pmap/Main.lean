/- Placeholder for the `pmap` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `pmap` is tracked in the README and awaits implementation. -/
def runPmap : Applet := unimplementedApplet

/-- Multicall registration for `pmap`. -/
abbrev PmapApplet := AppletTag "pmap" runPmap

end Lutils
