import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-256 checksums. -/
def runSha256sum : Applet := Checksum.run .sha256

end Lutils
