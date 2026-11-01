import Lutils.Shared.BaseCommand

namespace Lutils

/-- Encode or decode RFC 4648 Base64 data. -/
def runBase64 : Applet := BaseCommand.run (some (.power .base64))

end Lutils
