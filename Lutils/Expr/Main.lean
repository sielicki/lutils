/- Placeholder for the `expr` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `expr` is tracked in the README and awaits implementation. -/
def runExpr : Applet := unimplementedApplet

/-- Multicall registration for `expr`. -/
abbrev ExprApplet := AppletTag "expr" runExpr

end Lutils
