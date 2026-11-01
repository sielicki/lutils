import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-512 checksums. -/
def runSha512sum : Applet := Checksum.run .sha512

/-- Multicall registration for `sha512sum`. -/
abbrev Sha512sumApplet := AppletTag "sha512sum" runSha512sum

end Lutils
