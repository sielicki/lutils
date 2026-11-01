import Lutils.Shared.BaseCommand

namespace Lutils

/-- Encode or decode RFC 4648 Base32 data. -/
def runBase32 : Applet := BaseCommand.run (some (.power .base32))

/-- Multicall registration for `base32`. -/
abbrev Base32Applet := AppletTag "base32" runBase32

end Lutils
