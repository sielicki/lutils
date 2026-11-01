/- Placeholder for the `chacl` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `chacl` is tracked in the README and awaits implementation. -/
def runChacl : Applet := unimplementedApplet

/-- Multicall registration for `chacl`. -/
abbrev ChaclApplet := AppletTag "chacl" runChacl

end Lutils
