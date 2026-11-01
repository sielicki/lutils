/- Head utility implementation. -/
import Lutils.Shared.HeadTail

namespace Lutils

/-- `head`: output the first part of files. -/
def runHead : Applet := runHeadTail .head

end Lutils
