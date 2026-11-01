/- Placeholder for the `pgrep` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `pgrep` is tracked in the README and awaits implementation. -/
def runPgrep : Applet := unimplementedApplet

/-- Multicall registration for `pgrep`. -/
abbrev PgrepApplet := AppletTag "pgrep" runPgrep

end Lutils
