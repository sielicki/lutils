import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify MD5 checksums. -/
def runMd5sum : Applet := Checksum.run .md5

end Lutils
