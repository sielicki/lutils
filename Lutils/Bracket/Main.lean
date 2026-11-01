/- Placeholder for the `[` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `[` is tracked in the README and awaits implementation. -/
def runBracket : Applet := unimplementedApplet

/-- Multicall registration for `[`. -/
abbrev BracketApplet := AppletTag "[" runBracket

end Lutils
