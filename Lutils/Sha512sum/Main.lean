import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-512 checksums. -/
def runSha512sum : Applet := Checksum.run .sha512

end Lutils
