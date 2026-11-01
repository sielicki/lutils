import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-224 checksums. -/
def runSha224sum : Applet := Checksum.run .sha224

/-- Multicall registration for `sha224sum`. -/
abbrev Sha224sumApplet := AppletTag "sha224sum" runSha224sum

end Lutils
