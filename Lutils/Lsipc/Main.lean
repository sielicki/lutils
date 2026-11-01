/- Placeholder for the `lsipc` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `lsipc` is tracked in the README and awaits implementation. -/
def runLsipc : Applet := unimplementedApplet

/-- Multicall registration for `lsipc`. -/
abbrev LsipcApplet := AppletTag "lsipc" runLsipc

end Lutils
