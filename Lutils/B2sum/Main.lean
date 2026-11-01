import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify BLAKE2b checksums. -/
def runB2sum : Applet := Checksum.runB2sum

/-- Multicall registration for `b2sum`. -/
abbrev B2sumApplet := AppletTag "b2sum" runB2sum

end Lutils
