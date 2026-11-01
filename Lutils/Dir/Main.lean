/- Placeholder for the `dir` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `dir` is tracked in the README and awaits implementation. -/
def runDir : Applet := unimplementedApplet

/-- Multicall registration for `dir`. -/
abbrev DirApplet := AppletTag "dir" runDir

end Lutils
