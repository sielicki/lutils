/- Placeholder for the `nohup` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `nohup` is tracked in the README and awaits implementation. -/
def runNohup : Applet := unimplementedApplet

/-- Multicall registration for `nohup`. -/
abbrev NohupApplet := AppletTag "nohup" runNohup

end Lutils
