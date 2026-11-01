"""Isolated execution and snapshots shared by conformance and mutation checks."""

import os
from pathlib import Path
import re
import selectors
import stat
import subprocess
import tempfile
import time
from functools import lru_cache


REFERENCE_ENV = {
    "find": "LUTILS_FINDUTILS_BIN",
    "xargs": "LUTILS_FINDUTILS_BIN",
    "diff": "LUTILS_DIFFUTILS_BIN",
    "sed": "LUTILS_SED_BIN",
    "grep": "LUTILS_GREP_BIN",
    "cmp": "LUTILS_DIFFUTILS_BIN",
    "diff3": "LUTILS_DIFFUTILS_BIN",
    "sdiff": "LUTILS_DIFFUTILS_BIN",
}


class ExecutionTimeout(RuntimeError):
    """A command did not finish or produce its requested output in time."""


@lru_cache(maxsize=None)
def validate_locale(locale: str) -> None:
    """Reject unavailable locales before comparing two misleading C fallbacks."""
    if not locale or "\0" in locale:
        raise ValueError(f"invalid locale: {locale!r}")
    environment = {**os.environ, "LC_ALL": locale, "LANG": locale, "LANGUAGE": ""}
    probe = subprocess.run(["locale", "charmap"], env=environment,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if probe.returncode or probe.stderr:
        raise RuntimeError(f"locale {locale!r} is unavailable: {probe.stderr.strip()}")


def reference_command(family: str, util: str) -> list[str]:
    if family == "gnu":
        variable = REFERENCE_ENV.get(util, "LUTILS_GNU_BIN")
        applet = util
    elif family == "uutils":
        variable = "LUTILS_UUTILS_BIN"
        applet = "uutils-" + util
    elif family in ("util-linux", "procps", "uutils-procps", "acl", "hostname", "shadow", "shadow-su", "tar", "plocate"):
        variable = {
            "util-linux": "LUTILS_UTIL_LINUX_BIN", "procps": "LUTILS_PROCPS_BIN",
            "uutils-procps": "LUTILS_UUTILS_PROCPS_BIN",
            "acl": "LUTILS_ACL_BIN", "hostname": "LUTILS_HOSTNAME_BIN",
            "shadow": "LUTILS_SHADOW_BIN", "shadow-su": "LUTILS_SU_BIN",
            "tar": "LUTILS_TAR_BIN", "plocate": "LUTILS_PLOCATE_BIN",
        }[family]
        applet = "plocate" if family == "plocate" and util == "locate" else util
    else:
        raise ValueError(f"no executable reference for {family}")
    directory = os.environ.get(variable)
    if not directory:
        raise RuntimeError(f"missing {variable}; run inside `nix develop`")
    binary = Path(directory) / applet
    if not binary.is_file():
        raise RuntimeError(f"reference binary unavailable: {binary}")
    return [str(binary)]


def snapshot(work: Path) -> tuple:
    """Record observable files, ACLs, and hard-link relationships."""
    paths = sorted(work.rglob("*"))
    link_groups: dict[tuple[int, int], list[str]] = {}
    for path in paths:
        info = path.lstat()
        if stat.S_ISREG(info.st_mode):
            link_groups.setdefault((info.st_dev, info.st_ino), []).append(str(path.relative_to(work)))
    result = []
    for path in paths:
        info = path.lstat()
        mode = stat.S_IMODE(info.st_mode)
        if stat.S_ISLNK(info.st_mode):
            kind, content = "symlink", os.readlink(path)
        elif stat.S_ISDIR(info.st_mode):
            kind, content = "dir", None
        elif stat.S_ISREG(info.st_mode):
            kind, content = "file", path.read_bytes()
        elif stat.S_ISFIFO(info.st_mode):
            kind, content = "fifo", None
        elif stat.S_ISCHR(info.st_mode):
            kind, content = "character device", None
        elif stat.S_ISBLK(info.st_mode):
            kind, content = "block device", None
        elif stat.S_ISSOCK(info.st_mode):
            kind, content = "socket", None
        else:
            kind, content = "special", None
        acls = ()
        if stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode):
            acls = tuple((name, os.getxattr(path, name)) for name in sorted(os.listxattr(path))
                         if name in ("system.posix_acl_access", "system.posix_acl_default"))
        links = ()
        if stat.S_ISREG(info.st_mode):
            group = link_groups[(info.st_dev, info.st_ino)]
            if len(group) > 1:
                links = tuple(group)
        result.append((str(path.relative_to(work)), kind, mode, info.st_uid,
                       info.st_gid, content, acls, links))
    return tuple(result)


def prepare(work: Path, case) -> None:
    for name in case.dirs:
        (work / name).mkdir(parents=True, exist_ok=True)
    for name, content in case.files:
        target = work / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    for name, target in case.links:
        link = work / name
        link.parent.mkdir(parents=True, exist_ok=True)
        link.symlink_to(target)


def fixture_snapshot(case) -> tuple:
    with tempfile.TemporaryDirectory(prefix="lutils-fixture-") as tmp:
        work = Path(tmp)
        prepare(work, case)
        return snapshot(work)


def execute(binary: list[str], case, *, timeout: float = 10,
            elapsed_out: list[float] | None = None) -> tuple:
    """Run a case in a fresh directory; return status, streams, and tree."""
    validate_locale(case.locale)
    with tempfile.TemporaryDirectory(prefix="lutils-reference-") as tmp:
        work = Path(tmp)
        prepare(work, case)
        env = {**os.environ, "LC_ALL": case.locale, "TZ": "UTC",
               "LANG": case.locale, "LANGUAGE": ""}
        def normalize(data, *, diagnostic=False):
            data = (data.replace(str(work).encode(), b"<WORK>")
                    .replace(str(binary[0]).encode(), case.util.encode()))
            if diagnostic and Path(binary[0]).name == "uutils-" + case.util:
                data = re.sub(rb"(?m)^uutils-" + re.escape(case.util.encode()) + rb":",
                              case.util.encode() + b":", data)
            return data
        if case.output_limit is not None:
            if case.output_limit <= 0:
                raise ValueError("output_limit must be positive")
            # Files avoid deadlock when a bounded-output command writes a large
            # diagnostic or does not consume its input.
            with tempfile.TemporaryFile() as input_file, tempfile.TemporaryFile() as stderr_file:
                input_file.write(case.stdin)
                input_file.seek(0)
                started = time.monotonic()
                process = subprocess.Popen([*binary, *case.args], cwd=work,
                                           stdin=input_file, stdout=subprocess.PIPE,
                                           stderr=stderr_file, env=env)
                try:
                    data = bytearray()
                    deadline = started + timeout
                    with selectors.DefaultSelector() as selector:
                        selector.register(process.stdout, selectors.EVENT_READ)
                        while len(data) < case.output_limit:
                            remaining = deadline - time.monotonic()
                            if remaining <= 0 or not selector.select(remaining):
                                raise ExecutionTimeout(f"{case.util} exceeded {timeout:g}s timeout")
                            chunk = os.read(process.stdout.fileno(), case.output_limit - len(data))
                            if not chunk:
                                break
                            data.extend(chunk)
                    if len(data) == case.output_limit:
                        # A command that has already exited with exactly this
                        # much output is not an unbounded stream.
                        try:
                            process.wait(timeout=0.1)
                            status = process.returncode
                        except subprocess.TimeoutExpired:
                            status = "prefix"
                            if process.poll() is None:
                                process.kill()
                            process.wait()
                    else:
                        try:
                            process.wait(timeout=max(0, deadline - time.monotonic()))
                        except subprocess.TimeoutExpired as error:
                            raise ExecutionTimeout(f"{case.util} exceeded {timeout:g}s timeout") from error
                        status = process.returncode
                    stderr_file.seek(0)
                    if elapsed_out is not None:
                        elapsed_out.append(time.monotonic() - started)
                    return (status, normalize(bytes(data)),
                            normalize(stderr_file.read(), diagnostic=True), snapshot(work))
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.wait()
                    process.stdout.close()
        started = time.monotonic()
        try:
            result = subprocess.run([*binary, *case.args], cwd=work,
                                    input=case.stdin, stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, env=env, timeout=timeout)
            if elapsed_out is not None:
                elapsed_out.append(time.monotonic() - started)
            return (result.returncode, normalize(result.stdout),
                    normalize(result.stderr, diagnostic=True), snapshot(work))
        except subprocess.TimeoutExpired as error:
            raise ExecutionTimeout(f"{case.util} exceeded {timeout:g}s timeout") from error


def describe_difference(expected: tuple, actual: tuple) -> str:
    parts = []
    for index, label in enumerate(("status", "stdout", "stderr")):
        if expected[index] != actual[index]:
            parts.append(f"{label}: expected {expected[index]!r}, got {actual[index]!r}"[:250])
    if expected[3] != actual[3]:
        before = {entry[0]: entry[1:] for entry in expected[3]}
        after = {entry[0]: entry[1:] for entry in actual[3]}
        names = sorted(name for name in before.keys() | after.keys()
                       if before.get(name) != after.get(name))
        parts.append("filesystem: " + ", ".join(names[:8]) +
                     (f" (+{len(names)-8} more)" if len(names) > 8 else ""))
    return "; ".join(parts)
