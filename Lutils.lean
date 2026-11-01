/-
lutils: Unix utilities reimplemented in Lean 4.

This root module re-exports each tracked utility and provides the dispatch
table used by the multicall binary (`Main.lean`) and by `lutils --list`.
Unimplemented utilities dispatch to a failing stub so conformance tests can
invoke them before their implementation is written.
-/
import Lutils.Arch.Main
import Lutils.B2sum.Main
import Lutils.Base32.Main
import Lutils.Base64.Main
import Lutils.Basename.Main
import Lutils.Basenc.Main
import Lutils.Blockdev.Main
import Lutils.Bracket.Main
import Lutils.Cal.Main
import Lutils.Cat.Main
import Lutils.Chacl.Main
import Lutils.Chcpu.Main
import Lutils.Chgrp.Main
import Lutils.Chmod.Main
import Lutils.Chown.Main
import Lutils.Chroot.Main
import Lutils.Cksum.Main
import Lutils.Cmp.Main
import Lutils.Comm.Main
import Lutils.Cp.Main
import Lutils.Csplit.Main
import Lutils.Ctrlaltdel.Main
import Lutils.Cut.Main
import Lutils.Date.Main
import Lutils.Dd.Main
import Lutils.Df.Main
import Lutils.Diff.Main
import Lutils.Diff3.Main
import Lutils.Dir.Main
import Lutils.Dircolors.Main
import Lutils.Dirname.Main
import Lutils.Dmesg.Main
import Lutils.Du.Main
import Lutils.Echo.Main
import Lutils.Env.Main
import Lutils.Expand.Main
import Lutils.Expr.Main
import Lutils.Factor.Main
import Lutils.False.Main
import Lutils.Fdisk.Main
import Lutils.Find.Main
import Lutils.Fmt.Main
import Lutils.Fold.Main
import Lutils.Free.Main
import Lutils.Fsfreeze.Main
import Lutils.Getfacl.Main
import Lutils.Grep.Main
import Lutils.Groups.Main
import Lutils.Head.Main
import Lutils.Hexdump.Main
import Lutils.Hostid.Main
import Lutils.Hostname.Main
import Lutils.Hugetop.Main
import Lutils.Id.Main
import Lutils.Install.Main
import Lutils.Join.Main
import Lutils.Kill.Main
import Lutils.Last.Main
import Lutils.Link.Main
import Lutils.Ln.Main
import Lutils.Locate.Main
import Lutils.Login.Main
import Lutils.Logname.Main
import Lutils.Ls.Main
import Lutils.Lsblk.Main
import Lutils.Lscpu.Main
import Lutils.Lsipc.Main
import Lutils.Lslocks.Main
import Lutils.Lsmem.Main
import Lutils.Lsns.Main
import Lutils.Mcookie.Main
import Lutils.Md5sum.Main
import Lutils.Mesg.Main
import Lutils.Mkdir.Main
import Lutils.Mkfifo.Main
import Lutils.Mknod.Main
import Lutils.Mktemp.Main
import Lutils.More.Main
import Lutils.Mount.Main
import Lutils.Mountpoint.Main
import Lutils.Mv.Main
import Lutils.Newgrp.Main
import Lutils.Nice.Main
import Lutils.Nl.Main
import Lutils.Nohup.Main
import Lutils.Nologin.Main
import Lutils.Nproc.Main
import Lutils.Numfmt.Main
import Lutils.Od.Main
import Lutils.Paste.Main
import Lutils.Pathchk.Main
import Lutils.Pgrep.Main
import Lutils.Pidof.Main
import Lutils.Pidwait.Main
import Lutils.Pinky.Main
import Lutils.Pkill.Main
import Lutils.Pmap.Main
import Lutils.Pr.Main
import Lutils.Printenv.Main
import Lutils.Printf.Main
import Lutils.Ps.Main
import Lutils.Ptx.Main
import Lutils.Pwd.Main
import Lutils.Pwdx.Main
import Lutils.Readlink.Main
import Lutils.Realpath.Main
import Lutils.Renice.Main
import Lutils.Rev.Main
import Lutils.Rm.Main
import Lutils.Rmdir.Main
import Lutils.Sdiff.Main
import Lutils.Sed.Main
import Lutils.Seq.Main
import Lutils.Setfacl.Main
import Lutils.Setpgid.Main
import Lutils.Setsid.Main
import Lutils.Sha1sum.Main
import Lutils.Sha224sum.Main
import Lutils.Sha256sum.Main
import Lutils.Sha384sum.Main
import Lutils.Sha512sum.Main
import Lutils.Shred.Main
import Lutils.Shuf.Main
import Lutils.Skill.Main
import Lutils.Slabtop.Main
import Lutils.Sleep.Main
import Lutils.Snice.Main
import Lutils.Sort.Main
import Lutils.Split.Main
import Lutils.Stat.Main
import Lutils.Stdbuf.Main
import Lutils.Stty.Main
import Lutils.Su.Main
import Lutils.Sum.Main
import Lutils.Sync.Main
import Lutils.Sysctl.Main
import Lutils.Tac.Main
import Lutils.Tail.Main
import Lutils.Tar.Main
import Lutils.Tee.Main
import Lutils.Test.Main
import Lutils.Timeout.Main
import Lutils.Tload.Main
import Lutils.Top.Main
import Lutils.Touch.Main
import Lutils.Tr.Main
import Lutils.True.Main
import Lutils.Truncate.Main
import Lutils.Tsort.Main
import Lutils.Tty.Main
import Lutils.Umount.Main
import Lutils.Uname.Main
import Lutils.Unexpand.Main
import Lutils.Uniq.Main
import Lutils.Unlink.Main
import Lutils.Updatedb.Main
import Lutils.Uptime.Main
import Lutils.Users.Main
import Lutils.Uuidgen.Main
import Lutils.Vdir.Main
import Lutils.Vmstat.Main
import Lutils.W.Main
import Lutils.Watch.Main
import Lutils.Wc.Main
import Lutils.Who.Main
import Lutils.Whoami.Main
import Lutils.Xargs.Main
import Lutils.Yes.Main

namespace Lutils

/-- Every tracked utility, in `--list` order (keep alphabetised). -/
def applets : List (String × Applet) :=
  [ ("[", runBracket)
  , ("arch", runArch)
  , ("b2sum", runB2sum)
  , ("base32", runBase32)
  , ("base64", runBase64)
  , ("basename", runBasename)
  , ("basenc", runBasenc)
  , ("blockdev", runBlockdev)
  , ("cal", runCal)
  , ("cat", runCat)
  , ("chacl", runChacl)
  , ("chcpu", runChcpu)
  , ("chgrp", runChgrp)
  , ("chmod", runChmod)
  , ("chown", runChown)
  , ("chroot", runChroot)
  , ("cksum", runCksum)
  , ("cmp", runCmp)
  , ("comm", runComm)
  , ("cp", runCp)
  , ("csplit", runCsplit)
  , ("ctrlaltdel", runCtrlaltdel)
  , ("cut", runCut)
  , ("date", runDate)
  , ("dd", runDd)
  , ("df", runDf)
  , ("diff", runDiff)
  , ("diff3", runDiff3)
  , ("dir", runDir)
  , ("dircolors", runDircolors)
  , ("dirname", runDirname)
  , ("dmesg", runDmesg)
  , ("du", runDu)
  , ("echo", runEcho)
  , ("env", runEnv)
  , ("expand", runExpand)
  , ("expr", runExpr)
  , ("factor", runFactor)
  , ("false", runFalse)
  , ("fdisk", runFdisk)
  , ("find", runFind)
  , ("fmt", runFmt)
  , ("fold", runFold)
  , ("free", runFree)
  , ("fsfreeze", runFsfreeze)
  , ("getfacl", runGetfacl)
  , ("grep", runGrep)
  , ("groups", runGroups)
  , ("head", runHead)
  , ("hexdump", runHexdump)
  , ("hostid", runHostid)
  , ("hostname", runHostname)
  , ("hugetop", runHugetop)
  , ("id", runId)
  , ("install", runInstall)
  , ("join", runJoin)
  , ("kill", runKill)
  , ("last", runLast)
  , ("link", runLink)
  , ("ln", runLn)
  , ("locate", runLocate)
  , ("login", runLogin)
  , ("logname", runLogname)
  , ("ls", runLs)
  , ("lsblk", runLsblk)
  , ("lscpu", runLscpu)
  , ("lsipc", runLsipc)
  , ("lslocks", runLslocks)
  , ("lsmem", runLsmem)
  , ("lsns", runLsns)
  , ("mcookie", runMcookie)
  , ("md5sum", runMd5sum)
  , ("mesg", runMesg)
  , ("mkdir", runMkdir)
  , ("mkfifo", runMkfifo)
  , ("mknod", runMknod)
  , ("mktemp", runMktemp)
  , ("more", runMore)
  , ("mount", runMount)
  , ("mountpoint", runMountpoint)
  , ("mv", runMv)
  , ("newgrp", runNewgrp)
  , ("nice", runNice)
  , ("nl", runNl)
  , ("nohup", runNohup)
  , ("nologin", runNologin)
  , ("nproc", runNproc)
  , ("numfmt", runNumfmt)
  , ("od", runOd)
  , ("paste", runPaste)
  , ("pathchk", runPathchk)
  , ("pgrep", runPgrep)
  , ("pidof", runPidof)
  , ("pidwait", runPidwait)
  , ("pinky", runPinky)
  , ("pkill", runPkill)
  , ("pmap", runPmap)
  , ("pr", runPr)
  , ("printenv", runPrintenv)
  , ("printf", runPrintf)
  , ("ps", runPs)
  , ("ptx", runPtx)
  , ("pwd", runPwd)
  , ("pwdx", runPwdx)
  , ("readlink", runReadlink)
  , ("realpath", runRealpath)
  , ("renice", runRenice)
  , ("rev", runRev)
  , ("rm", runRm)
  , ("rmdir", runRmdir)
  , ("sdiff", runSdiff)
  , ("sed", runSed)
  , ("seq", runSeq)
  , ("setfacl", runSetfacl)
  , ("setpgid", runSetpgid)
  , ("setsid", runSetsid)
  , ("sha1sum", runSha1sum)
  , ("sha224sum", runSha224sum)
  , ("sha256sum", runSha256sum)
  , ("sha384sum", runSha384sum)
  , ("sha512sum", runSha512sum)
  , ("shred", runShred)
  , ("shuf", runShuf)
  , ("skill", runSkill)
  , ("slabtop", runSlabtop)
  , ("sleep", runSleep)
  , ("snice", runSnice)
  , ("sort", runSort)
  , ("split", runSplit)
  , ("stat", runStat)
  , ("stdbuf", runStdbuf)
  , ("stty", runStty)
  , ("su", runSu)
  , ("sum", runSum)
  , ("sync", runSync)
  , ("sysctl", runSysctl)
  , ("tac", runTac)
  , ("tail", runTail)
  , ("tar", runTar)
  , ("tee", runTee)
  , ("test", runTest)
  , ("timeout", runTimeout)
  , ("tload", runTload)
  , ("top", runTop)
  , ("touch", runTouch)
  , ("tr", runTr)
  , ("true", runTrue)
  , ("truncate", runTruncate)
  , ("tsort", runTsort)
  , ("tty", runTty)
  , ("umount", runUmount)
  , ("uname", runUname)
  , ("unexpand", runUnexpand)
  , ("uniq", runUniq)
  , ("unlink", runUnlink)
  , ("updatedb", runUpdatedb)
  , ("uptime", runUptime)
  , ("users", runUsers)
  , ("uuidgen", runUuidgen)
  , ("vdir", runVdir)
  , ("vmstat", runVmstat)
  , ("w", runW)
  , ("watch", runWatch)
  , ("wc", runWc)
  , ("who", runWho)
  , ("whoami", runWhoami)
  , ("xargs", runXargs)
  , ("yes", runYes)
  ]

/-- Applet names, one per line as consumed by `lutils --list`. -/
def appletNames : List String := applets.map Prod.fst

/-- Look up an applet by name. -/
def findApplet (name : String) : Option Applet :=
  applets.lookup name

end Lutils
