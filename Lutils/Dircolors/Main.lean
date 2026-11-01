/- Placeholder for the `dircolors` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `dircolors` is tracked in the README and awaits implementation. -/
def runDircolors : Applet := unimplementedApplet

/-- Multicall registration for `dircolors`. -/
abbrev DircolorsApplet := AppletTag "dircolors" runDircolors

end Lutils
