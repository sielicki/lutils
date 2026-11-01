import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-256 checksums. -/
def runSha256sum : Applet := Checksum.run .sha256

/-- Multicall registration for `sha256sum`. -/
abbrev Sha256sumApplet := AppletTag "sha256sum" runSha256sum

end Lutils
