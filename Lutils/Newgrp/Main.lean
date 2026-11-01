/- Placeholder for the `newgrp` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `newgrp` is tracked in the README and awaits implementation. -/
def runNewgrp : Applet := unimplementedApplet

/-- Multicall registration for `newgrp`. -/
abbrev NewgrpApplet := AppletTag "newgrp" runNewgrp

end Lutils
