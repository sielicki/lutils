import Lutils.Shared.BaseCommand

namespace Lutils

/-- Encode or decode RFC 4648 Base32 data. -/
def runBase32 : Applet := BaseCommand.run (some (.power .base32))

end Lutils
