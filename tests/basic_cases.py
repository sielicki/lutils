"""One isolated behavioral or validation case for every otherwise untested utility.

These cases deliberately fail for stubs. Privileged and interactive commands use
nonexistent operands or read-only modes so the reference cannot change the host.
"""

import io
import os
from pathlib import Path
import tarfile

from corpus import Case

UTIL_LINUX = set("blockdev cal chcpu ctrlaltdel dmesg fdisk fsfreeze hexdump kill last lsblk lscpu lsipc lslocks lsmem lsns mcookie mesg more mount mountpoint nologin renice rev setpgid setsid umount uuidgen".split())
PROCPS = set("free hugetop pgrep pidof pidwait pkill pmap ps pwdx skill slabtop snice sysctl tload top uptime vmstat w watch".split())
ACL = {"chacl", "getfacl", "setfacl"}
SHADOW = {"login", "newgrp"}


def provider_for(util: str) -> str:
    if util in ("skill", "snice"):
        return "uutils-procps"
    if util in UTIL_LINUX:
        return "util-linux"
    if util in PROCPS:
        return "procps"
    if util in ACL:
        return "acl"
    if util in SHADOW:
        return "shadow"
    if util == "su":
        return "shadow-su"
    if util == "hostname":
        return "hostname"
    if util == "tar":
        return "tar"
    if util in ("locate", "updatedb"):
        return "plocate"
    return "gnu"


def archive() -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as output:
        item = tarfile.TarInfo("hello.txt")
        item.size = 6
        item.mtime = 0
        output.addfile(item, io.BytesIO(b"hello\n"))
    return buffer.getvalue()


def basic_cases(missing: set[str]) -> list[Case]:
    specs: dict[str, Case] = {}
    def add(util, args=(), *, stdin=b"", files=(), dirs=(), links=(), output_limit=None):
        if util in specs:
            raise ValueError(f"duplicate basic case for {util}")
        specs[util] = Case("basic", util, "baseline", args=tuple(args),
                           stdin=stdin, files=tuple(files), dirs=tuple(dirs),
                           links=tuple(links), output_limit=output_limit,
                           reference=provider_for(util))

    # Deterministic stdin transforms and checksums.
    for util in "b2sum sha1sum sha224sum sha384sum sha512sum sum".split():
        add(util, stdin=b"abc\n")
    add("basenc", ["--base64"], stdin=b"abc\n")
    for util in "fmt fold nl od pr hexdump more rev".split():
        add(util, stdin=b"alpha beta\ngamma\n")
    add("expand", ["-t", "4"], stdin=b"a\tb\n")
    add("unexpand", ["-a", "-t", "4"], stdin=b"a   b\n")
    add("paste", stdin=b"a\nb\n")
    add("ptx", stdin=b"one two\n")
    add("tsort", stdin=b"a b\nb c\n")
    add("shuf", stdin=b"only\n")
    add("dd", ["bs=2", "count=2", "status=none"], stdin=b"abcd")
    add("split", ["-b", "2", "-"], stdin=b"abcd")
    add("csplit", ["input", "/b/"], files=[("input", b"a\nb\n")])

    # Pure arguments, status, and environment.
    add("[", ["1", "-eq", "1", "]"])
    add("test", ["1", "-eq", "1"])
    add("arch")
    add("date", ["-u", "-d", "@0", "+%Y-%m-%d"])
    add("dir", ["-1", "."], files=[("alpha", b"a")])
    add("vdir", ["-1", "."], files=[("alpha", b"a")])
    add("dircolors", ["-b"])
    add("env", ["-i", "LUTILS_ENV=ok", "sh", "-c", 'printf "%s\\n" "$LUTILS_ENV"'])
    add("expr", ["1", "+", "2"])
    add("factor", ["12"])
    add("groups")
    add("hostid")
    add("id", ["-u"])
    add("logname")
    add("nice", ["-n", "0", "sh", "-c", "printf ok"])
    add("nohup", ["sh", "-c", "printf ok"])
    add("nproc")
    add("numfmt", ["--to=iec", "1024"])
    add("pathchk", ["-p", "name-exceeding-14-characters"])
    add("pinky", ["-s", "nobody"])
    add("printenv", ["HOME"])
    add("pwd", ["-P"])
    add("realpath", ["."])
    add("readlink", ["alias"], files=[("input", b"data")], links=[("alias", "input")])
    add("stat", ["-c", "%s", "input"], files=[("input", b"hello\n")])
    add("stdbuf", ["-o0", "sh", "-c", "printf ok"])
    add("sync", ["missing-file"])
    add("timeout", ["1", "sh", "-c", "printf ok"])
    add("tty")
    add("uname", ["-s"])
    add("users", ["--invalid-option"])
    add("who", ["--invalid-option"])
    add("whoami")
    add("yes", ["ok"], output_limit=9)

    # Small filesystem fixtures. All effects stay within execute()'s temp dir.
    other_groups = sorted(set(os.getgroups()) - {os.getgid()})
    target_group = other_groups[0] if other_groups else (12345 if os.getgid() != 12345 else 12346)
    add("chgrp", [str(target_group), "input"], files=[("input", b"data")])
    add("chmod", ["600", "input"], files=[("input", b"data")])
    target_user = 12345 if os.getuid() != 12345 else 12346
    add("chown", [str(target_user), "input"], files=[("input", b"data")])
    add("comm", ["left", "right"], files=[("left", b"a\nb\n"), ("right", b"b\nc\n")])
    add("cmp", ["left", "right"], files=[("left", b"left\n"), ("right", b"right\n")])
    add("diff3", ["left", "base", "right"], files=[("left", b"left\n"), ("base", b"base\n"), ("right", b"right\n")])
    add("sdiff", ["left", "right"], files=[("left", b"a\n"), ("right", b"b\n")])
    add("du", ["-s", "input"], files=[("input", b"data")])
    add("install", ["input", "output"], files=[("input", b"data")])
    add("join", ["left", "right"], files=[("left", b"a 1\n"), ("right", b"a 2\n")])
    add("link", ["input", "alias"], files=[("input", b"data")])
    add("ln", ["-s", "input", "alias"], files=[("input", b"data")])
    add("mkfifo", ["pipe"])
    add("mknod", ["pipe", "p"])
    add("shred", ["-n", "1", "-z", "input"], files=[("input", b"abcd")])
    add("touch", ["new-file"])
    add("truncate", ["-s", "2", "input"], files=[("input", b"data")])
    add("unlink", ["input"], files=[("input", b"data")])
    add("tar", ["-tf", "archive.tar"], files=[("archive.tar", archive())])

    # Utility-specific safe validation and read-only cases.
    add("blockdev", ["--getsz", "missing-device"])
    add("cal", ["1", "2000"])
    add("chcpu", ["--enable", "invalid-cpu"])
    add("chroot", ["missing-root", "true"])
    add("ctrlaltdel", ["invalid-mode"])
    add("df", ["missing-path"])
    add("dmesg", ["--time-format=invalid"])
    add("fdisk", ["-l", "missing-device"])
    add("free", ["-z"])
    add("fsfreeze", ["--freeze", "missing-path"])
    add("getfacl", ["input"], files=[("input", b"data")])
    add("setfacl", ["-m", "u:12345:r--", "input"], files=[("input", b"data")])
    add("chacl", ["-l", "input"], files=[("input", b"data")])
    add("hostname", ["-s"])
    add("hugetop", ["--invalid-option"])
    add("kill", ["-s", "LUTILS_INVALID_SIGNAL"])
    add("last", ["-f", "missing-utmp"])
    add("locate", ["-d", "missing.db", "lutils-impossible-pattern"])
    add("login", ["-f", "lutils-nonexistent-user-8b0d"])
    add("lsblk", ["missing-device"])
    add("lscpu", ["--parse=CPU"])
    add("lsipc", ["--output", "BAD"])
    add("lslocks", ["--output", "BAD"])
    add("lsmem", ["--output", "RANGE"])
    add("lsns", ["--output", "BAD"])
    add("mcookie", ["--max-size", "invalid"])
    add("mesg")
    add("mktemp", ["invalid-template"])
    add("mount", ["--invalid-option"])
    add("mountpoint", ["."])
    add("newgrp", ["lutils-nonexistent-group-8b0d"])
    add("nologin")
    add("pgrep", ["lutils-impossible-process-8b0d"])
    add("pidof", ["lutils-impossible-process-8b0d"])
    add("pidwait", ["lutils-impossible-process-8b0d"])
    add("pkill", ["lutils-impossible-process-8b0d"])
    add("pmap", ["999999999"])
    add("ps", ["-p", "999999999", "-o", "pid="])
    add("pwdx", ["999999999"])
    add("renice", ["-n", "1", "-p", "999999999"])
    add("setpgid", ["sh", "-c", "printf ok"])
    add("setsid", ["sh", "-c", "printf ok"])
    add("skill", ["-l"])
    add("slabtop", ["--invalid-option"])
    add("snice", ["-l"])
    add("stty", ["-a"])
    add("su", ["lutils-nonexistent-user-8b0d", "-c", "true"])
    add("sysctl", ["-n", "kernel.ostype"])
    add("tload", ["-d", "invalid"])
    add("top", ["-o", "INVALID"])
    add("umount", ["missing-path"])
    add("updatedb", ["--config-file", "config", "--database-root", "empty",
                      "--output", "db", "--require-visibility", "no"],
        dirs=["empty"], files=[("config", b"")])
    add("uptime", ["-s"])
    add("uuidgen", ["--namespace", "@dns", "--name", "example.com", "--md5"])
    add("vmstat", ["-z"])
    add("w", ["--invalid-option"])
    add("watch", ["-n", "invalid", "true"])

    omitted = missing - specs.keys()
    if omitted:
        raise ValueError(f"missing basic cases for: {', '.join(sorted(omitted))}")
    return [specs[util] for util in sorted(missing)]
