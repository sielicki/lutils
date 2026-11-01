/- Placeholder for the `skill` utility. -/
import Lutils.Shared.Stub

namespace Lutils

/-- `skill` is tracked in the README and awaits implementation. -/
def runSkill : Applet := unimplementedApplet

/-- Multicall registration for `skill`. -/
abbrev SkillApplet := AppletTag "skill" runSkill

end Lutils
