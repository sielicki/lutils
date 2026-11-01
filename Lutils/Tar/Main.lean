/- Placeholder for the `tar` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `tar` is tracked in the README and awaits implementation. -/
def runTar : Applet := unimplementedApplet

/-- Multicall registration for `tar`. -/
abbrev TarApplet := AppletTag "tar" runTar

end Lutils
