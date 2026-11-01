"""Behavioral cases for utility families beyond the initial coreutils matrix.

Each case has a controlled input or filesystem effect. References are selected
explicitly so these cases can be run even while the corresponding applet is a
stub. Privileged and interactive commands need a separate isolated test setup.
"""

import io
import tarfile

from corpus import Case


def _archive() -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as archive:
        item = tarfile.TarInfo("hello.txt")
        item.size = 6
        item.mode = 0o640
        item.mtime = 0
        archive.addfile(item, io.BytesIO(b"hello\n"))
    return buffer.getvalue()


def family_cases() -> list[Case]:
    out: list[Case] = []

    def add(util: str, name: str, args=(), *, reference="gnu", stdin=b"",
            files=(), dirs=(), links=(), min_runtime=None, max_runtime=None):
        out.append(Case("behavior", util, name, args=tuple(args), stdin=stdin,
                        files=tuple(files), dirs=tuple(dirs), links=tuple(links),
                        reference=reference, min_runtime=min_runtime,
                        max_runtime=max_runtime))

    # Find: selection, traversal limits, symlink policy, binary-safe output,
    # and a mutating action whose result is checked by the filesystem snapshot.
    tree = (("a.txt", b"alpha\n"), ("b.tmp", b"remove\n"),
            ("sub/c.txt", b"gamma\n"), ("sub/d.tmp", b"remove\n"))
    add("find", "name-and-type", [".", "-type", "f", "-name", "a.txt"],
        files=tree, dirs=["sub"])
    add("find", "max-depth", [".", "-maxdepth", "1", "-type", "f",
                              "-name", "*.txt"],
        files=tree, dirs=["sub"])
    add("find", "empty-directory", [".", "-type", "d", "-empty"],
        dirs=["empty", "nonempty"], files=[("nonempty/child", b"x")])
    add("find", "print-null", [".", "-name", "a.txt", "-print0"], files=tree)
    add("find", "follow-symlink", ["-L", ".", "-type", "f", "-name", "alias"],
        files=[("a.txt", b"x")], links=[("alias", "a.txt")])
    add("find", "delete-matches", [".", "-name", "*.tmp", "-delete"],
        files=tree, dirs=["sub"])

    # Xargs: token grouping, NUL separators, replacement, and empty input.
    add("xargs", "groups-of-two", ["-n", "2", "printf", "<%s,%s>\\n"],
        stdin=b"a b c d\n")
    add("xargs", "null-separated", ["-0", "-n", "1", "printf", "[%s]\\n"],
        stdin=b"a b\0c\0")
    add("xargs", "replacement", ["-I", "{}", "printf", "<%s>\\n", "{}"],
        stdin=b"first item\nsecond\n")
    add("xargs", "no-run-if-empty", ["-r", "printf", "unexpected"], stdin=b"")

    left = (("left", b"one\ntwo\nthree\n"),
            ("right", b"one\nTWO\nthree\n"))
    add("diff", "unified-change", ["-u", "--label", "left", "--label", "right",
                                   "left", "right"], files=left)
    add("diff", "ignore-space-change", ["-b", "left", "right"],
        files=[("left", b"a b\n"), ("right", b"a  b\n")])
    add("diff", "identical-files", ["-q", "left", "right"],
        files=[("left", b"same\n"), ("right", b"same\n")])
    add("cmp", "first-difference", ["left", "right"], files=left)
    add("cmp", "silent-equal-prefix", ["-s", "-n", "3", "left", "right"],
        files=left)
    add("comm", "common-only", ["-12", "left", "right"],
        files=[("left", b"a\nb\nd\n"), ("right", b"b\nc\nd\n")])
    add("comm", "left-only", ["-23", "left", "right"],
        files=[("left", b"a\nb\nd\n"), ("right", b"b\nc\nd\n")])
    add("diff3", "nonconflicting-merge", ["-m", "left", "base", "right"],
        files=[("left", b"ONE\na\nb\nc\nd\ne\nlast\n"),
               ("base", b"one\na\nb\nc\nd\ne\nlast\n"),
               ("right", b"one\na\nb\nc\nd\ne\nLAST\n")])
    add("diff3", "conflicting-merge", ["-m", "left", "base", "right"],
        files=[("left", b"ONE\n"), ("base", b"one\n"),
               ("right", b"UNO\n")])
    add("sdiff", "side-by-side-width", ["--width=30", "left", "right"],
        files=left)

    # Sed: addresses, extended patterns, multiple expressions, and in-place
    # editing. The latter checks the resulting file, not just command status.
    add("sed", "address-range", ["-n", "2,3p"], stdin=b"a\nb\nc\nd\n")
    add("sed", "capture-groups", ["-E", "s/([a-z]+):([0-9]+)/\\2=\\1/g"],
        stdin=b"a:1 b:22\n")
    add("sed", "multiple-expressions", ["-e", "1d", "-e", "s/a/A/g"],
        stdin=b"first\nalpha\nbeta\n")
    add("sed", "in-place-edit", ["-i", "s/red/blue/g", "input"],
        files=[("input", b"red\ngreen red\n")])
    add("sed", "unterminated-last-line", ["s/o/O/g"], stdin=b"foo")

    # Tar: compare listing, extraction to stdout, and the resulting file tree.
    archive = (("archive.tar", _archive()),)
    add("tar", "list-archive", ["-tf", "archive.tar"],
        reference="tar", files=archive)
    add("tar", "extract-to-stdout", ["-xOf", "archive.tar", "hello.txt"],
        reference="tar", files=archive)
    add("tar", "extract-files", ["-xf", "archive.tar"],
        reference="tar", files=archive)

    # These are read-only or local, unprivileged behaviors from other families.
    add("getfacl", "concise-permissions", ["-cp", "input"],
        reference="acl", files=[("input", b"data")])
    add("setfacl", "change-mode-bits", ["-m", "u::rwx,g::---,o::---", "input"],
        reference="acl", files=[("input", b"data")])
    add("setfacl", "named-user-acl", ["-m", "u:12345:r--", "input"],
        reference="acl", files=[("input", b"data")])
    add("cal", "leap-february", ["2", "2000"], reference="util-linux")
    add("hexdump", "canonical-binary", ["-C"], reference="util-linux",
        stdin=b"a\x00b\xff\n")
    add("rev", "multiple-lines", reference="util-linux", stdin=b"abc\n12\n")
    add("mountpoint", "ordinary-directory", ["-q", "ordinary"],
        reference="util-linux", dirs=["ordinary"])
    add("hostname", "current-name", reference="hostname")
    add("sysctl", "kernel-name", ["-n", "kernel.ostype"], reference="procps")
    add("sleep", "minimum-duration", ["0.5"], min_runtime=0.4)
    add("timeout", "pass-through", ["1", "sh", "-c", "printf ok"])
    add("timeout", "deadline", ["0.2", "sh", "-c",
                                "printf start; sleep 1; printf end"],
        min_runtime=0.1, max_runtime=0.6)
    return out
