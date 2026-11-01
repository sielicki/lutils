/- Placeholder for the `hexdump` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `hexdump` is tracked in the README and awaits implementation. -/
def runHexdump : Applet := unimplementedApplet

/-- Multicall registration for `hexdump`. -/
abbrev HexdumpApplet := AppletTag "hexdump" runHexdump

end Lutils
