/- Tail utility implementation. -/
import Lutils.Shared.HeadTail

namespace Lutils

/-- `tail`: output the last part of files (without `-f` for now). -/
def runTail : Applet := runHeadTail .tail

/-- Multicall registration for `tail`. -/
abbrev TailApplet := AppletTag "tail" runTail

end Lutils
