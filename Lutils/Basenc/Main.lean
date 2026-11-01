import Lutils.Shared.BaseCommand

namespace Lutils

/-- Encode or decode one of the `basenc` alphabets. -/
def runBasenc : Applet := BaseCommand.run none

/-- Multicall registration for `basenc`. -/
abbrev BasencApplet := AppletTag "basenc" runBasenc

end Lutils
