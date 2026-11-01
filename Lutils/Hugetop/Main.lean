/- Placeholder for the `hugetop` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `hugetop` is tracked in the README and awaits implementation. -/
def runHugetop : Applet := unimplementedApplet

/-- Multicall registration for `hugetop`. -/
abbrev HugetopApplet := AppletTag "hugetop" runHugetop

end Lutils
