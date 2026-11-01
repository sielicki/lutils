import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-384 checksums. -/
def runSha384sum : Applet := Checksum.run .sha384

/-- Multicall registration for `sha384sum`. -/
abbrev Sha384sumApplet := AppletTag "sha384sum" runSha384sum

end Lutils
