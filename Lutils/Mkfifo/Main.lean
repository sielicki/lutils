/- Placeholder for the `mkfifo` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `mkfifo` is tracked in the README and awaits implementation. -/
def runMkfifo : Applet := unimplementedApplet

/-- Multicall registration for `mkfifo`. -/
abbrev MkfifoApplet := AppletTag "mkfifo" runMkfifo

end Lutils
