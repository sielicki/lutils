/- Placeholder for the `chroot` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `chroot` is tracked in the README and awaits implementation. -/
def runChroot : Applet := unimplementedApplet

/-- Multicall registration for `chroot`. -/
abbrev ChrootApplet := AppletTag "chroot" runChroot

end Lutils
