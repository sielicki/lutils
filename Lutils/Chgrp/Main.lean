/- Placeholder for the `chgrp` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `chgrp` is tracked in the README and awaits implementation. -/
def runChgrp : Applet := unimplementedApplet

/-- Multicall registration for `chgrp`. -/
abbrev ChgrpApplet := AppletTag "chgrp" runChgrp

end Lutils
