import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-1 checksums. -/
def runSha1sum : Applet := Checksum.run .sha1

end Lutils
