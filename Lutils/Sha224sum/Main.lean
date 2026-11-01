import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-224 checksums. -/
def runSha224sum : Applet := Checksum.run .sha224

end Lutils
