import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-384 checksums. -/
def runSha384sum : Applet := Checksum.run .sha384

end Lutils
