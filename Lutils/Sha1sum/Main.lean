import Lutils.Shared.Checksum

namespace Lutils

/-- Print or verify SHA-1 checksums. -/
def runSha1sum : Applet := Checksum.run .sha1

/-- Multicall registration for `sha1sum`. -/
abbrev Sha1sumApplet := AppletTag "sha1sum" runSha1sum

end Lutils
