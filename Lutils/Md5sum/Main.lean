import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify MD5 checksums. -/
def runMd5sum : Applet := Checksum.run .md5

/-- Multicall registration for `md5sum`. -/
abbrev Md5sumApplet := AppletTag "md5sum" runMd5sum

end Lutils
