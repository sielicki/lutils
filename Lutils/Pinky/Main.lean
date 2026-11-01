/- Placeholder for the `pinky` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `pinky` is tracked in the README and awaits implementation. -/
def runPinky : Applet := unimplementedApplet

/-- Multicall registration for `pinky`. -/
abbrev PinkyApplet := AppletTag "pinky" runPinky

end Lutils
