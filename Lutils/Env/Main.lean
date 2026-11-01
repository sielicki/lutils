/- Placeholder for the `env` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `env` is tracked in the README and awaits implementation. -/
def runEnv : Applet := unimplementedApplet

/-- Multicall registration for `env`. -/
abbrev EnvApplet := AppletTag "env" runEnv

end Lutils
