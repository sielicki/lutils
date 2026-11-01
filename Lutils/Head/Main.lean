/- Head utility implementation. -/
import Lutils.Shared.HeadTail

namespace Lutils

/-- `head`: output the first part of files. -/
def runHead : Applet := runHeadTail .head

/-- Multicall registration for `head`. -/
abbrev HeadApplet := AppletTag "head" runHead

end Lutils
