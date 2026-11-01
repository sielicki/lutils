"""Reference-backed conformance cases. Upstream source and binaries come from Nix."""

from dataclasses import dataclass, replace
from pathlib import Path
import re
import subprocess
from reference import (describe_difference, execute, fixture_snapshot,
                       reference_command, validate_locale)


DEFAULT_LOCALES = ("C", "C.UTF-8")


@dataclass(frozen=True)
class Case:
    family: str
    util: str
    name: str
    args: tuple[str, ...] = ()
    stdin: bytes = b""
    files: tuple[tuple[str, bytes], ...] = ()
    dirs: tuple[str, ...] = ()
    expected: bytes | None = None
    source: str | None = None
    marker: str | None = None
    reference: str | None = None
    output_limit: int | None = None
    links: tuple[tuple[str, str], ...] = ()
    min_runtime: float | None = None
    max_runtime: float | None = None
    locale: str = "C"
    locales: tuple[str, ...] | None = None


def permute_locales(corpus: list[Case], locales: tuple[str, ...] = DEFAULT_LOCALES) -> list[Case]:
    """Run reference-backed inputs under each locale, unless a case restricts them."""
    selected = tuple(dict.fromkeys(locales))
    if not selected:
        raise ValueError("at least one locale is required")
    for locale in selected:
        validate_locale(locale)
    out = []
    for case in corpus:
        if case.expected is not None:
            out.append(case)
            continue
        allowed = set(case.locales) if case.locales is not None else set(selected)
        for locale in selected:
            if locale not in allowed:
                continue
            out.append(replace(case, locale=locale))
    return out


def duration_error(case: Case, elapsed: float) -> str | None:
    if case.min_runtime is not None and elapsed < case.min_runtime:
        return f"completed in {elapsed:.3f}s, expected at least {case.min_runtime:.3f}s"
    if case.max_runtime is not None and elapsed > case.max_runtime:
        return f"completed in {elapsed:.3f}s, expected at most {case.max_runtime:.3f}s"
    return None


def tracked_utilities() -> set[str]:
    readme = Path(__file__).resolve().parents[1] / "README.md"
    return {match.group(1) for line in readme.read_text().splitlines()
            if (match := re.match(r"^\| [^|]+ \| `([^`]+)` \| (?:Yes|No) \|", line))}


def validate_coverage(binary: Path, corpus: list[Case]) -> None:
    registered = set(subprocess.check_output([str(binary), "--list"], text=True).splitlines())
    tracked = tracked_utilities()
    tested = {case.util for case in corpus}
    if not registered == tracked == tested:
        raise RuntimeError("utility coverage mismatch: "
                           f"registered without tests={sorted(registered-tested)}, "
                           f"README without tests={sorted(tracked-tested)}, "
                           f"tested without applet={sorted(tested-registered)}")


def cases(sources: Path, locales: tuple[str, ...] = DEFAULT_LOCALES) -> list[Case]:
    out: list[Case] = []
    def add(family, util, name, args=(), stdin=b"", files=(), dirs=(), expected=None,
            source=None, marker=None):
        out.append(Case(family, util, name, tuple(args), stdin, tuple(files),
                        tuple(dirs), expected, source, marker))

    # Broad command-line and stream matrices; both reference families are run.
    paths = ["/usr/bin", "/usr/bin/", "usr/bin", "//usr///bin//", "/", ".",
             "", "file.txt", "a/b/c.tar.gz", "a//b///c", "a/./b", "--",
             "café/中🙂/"]
    for family in ("gnu", "uutils"):
        for util in ("basename", "dirname"):
            for i, path in enumerate(paths):
                add(family, util, f"path-{i}", ["--", path])
            for i, path in enumerate(["/usr/bin", "a/b/c.txt", "file.txt", "/", "a///"]):
                if util == "basename":
                    add(family, util, f"suffix-{i}", [path, ".txt"])
                    add(family, util, f"zero-{i}", ["-z", path])
                else:
                    add(family, util, f"zero-{i}", ["-z", path])
            add(family, util, "multiple", ["-a", "a/b", "x/y"] if util == "basename" else ["a/b", "x/y"])
        for i, args in enumerate([[], ["hello"], ["-n", "hello"], ["hello", "world"],
                                  ["-e", "a\\tb"], ["-e", "a\\nb"], ["-e", "\\x41"],
                                  ["-E", "a\\tb"], ["-n", "-e", "hi\\n"], ["--", "-n"]]):
            add(family, "echo", f"args-{i}", args)
        for i, args in enumerate([["3"], ["0"], ["1", "5"], ["5", "-1", "1"],
                                  ["-s", ",", "2", "5"], ["-w", "8", "12"],
                                  ["0.1", "0.2", "0.9"], ["-f", "%.2f", "1", "3"],
                                  ["-s", "", "1", "4"]]):
            add(family, "seq", f"args-{i}", args)
        lines = b"alpha\nbeta\ngamma\ndelta\nepsilon\n"
        for util in ("cat", "head", "tail", "wc", "sort", "uniq", "cut", "tr", "tac"):
            if util in ("head", "tail"):
                variants = [[], ["-n", "1"], ["-n", "2"], ["-n", "0"], ["-c", "3"],
                            ["-c", "0"], ["-n", "+2"]]
            elif util == "cat":
                variants = [[], ["-n"], ["-b"], ["-s"], ["-E"], ["-T"]]
            elif util == "wc":
                variants = [[], ["-l"], ["-w"], ["-c"], ["-m"]]
            elif util == "sort":
                variants = [[], ["-r"], ["-u"], ["-f"]]
            elif util == "cut":
                variants = [["-c", "1"], ["-c", "1-3"], ["-b", "2-4"], ["-f", "1"]]
            elif util == "tr":
                variants = [["a-z", "A-Z"], ["a", "x"], ["-d", "a"]]
            else:
                variants = [[], ["-c"]] if util == "uniq" else [[]]
            for i, args in enumerate(variants):
                add(family, util, f"stdin-{i}", args, lines)
                if util not in ("tr",):
                    add(family, util, f"file-{i}", [*args, "input"], files=[("input", lines)])
        for i, args in enumerate([["."], ["-a", "."], ["-1", "."], ["-d", "."]]):
            add(family, "ls", f"listing-{i}", args, files=[("alpha", b"a"), ("beta", b"b")])
        for i, args in enumerate([["-p", "new"], ["-p", "a/b"], ["new"]]):
            add(family, "mkdir", f"create-{i}", args)
        for i, args in enumerate([["input", "output"], ["-n", "input", "output"]]):
            add(family, "cp", f"copy-{i}", args, files=[("input", b"content\n")])
            add(family, "mv", f"move-{i}", args, files=[("input", b"content\n")])
        for i, args in enumerate([["input"], ["-f", "input"], ["-v", "input"]]):
            add(family, "rm", f"remove-{i}", args, files=[("input", b"content\n")])
        add(family, "rmdir", "empty-directory", ["empty"], dirs=["empty"])
        for i, args in enumerate([["output"], ["-a", "output"]]):
            add(family, "tee", f"write-{i}", args, b"alpha\nbeta\n")
        for util in ("base32", "base64", "md5sum", "sha256sum", "cksum"):
            add(family, util, "short-input", stdin=b"abc\n")
            add(family, util, "empty-input")
        add(family, "sleep", "zero", ["0"])
        for util in ("true", "false"):
            add(family, util, "status")
        for i, args in enumerate([["-n", "hello"], ["%s:%d", "ok", "7"]]):
            if i == 1:
                add(family, "printf", f"format-{i}", args)
    for i, args in enumerate([["-e", "s/a/x/g"], ["-n", "p"], ["-e", "2d"]]):
        add("gnu", "sed", f"script-{i}", args, b"alpha\nbeta\n")
    for i, args in enumerate([["-n", "3"], ["-d", "x"]]):
        add("gnu", "xargs", f"args-{i}", args, b"x\ny\n")
    for i, args in enumerate([["-maxdepth", "0"], ["-type", "f"], ["-name", "alpha"]]):
        add("gnu", "find", f"search-{i}", [".", *args], files=[("alpha", b"a")])
    for i, args in enumerate([["a", "b"],
                              ["-u", "--label", "a", "--label", "b", "a", "b"]]):
        add("gnu", "diff", f"files-{i}", args, files=[("a", b"one\n"), ("b", b"two\n")])

    # Literal cases from NetBSD ATF and FreeBSD ATF scripts. The source marker
    # is checked in the pinned upstream file before executing each case.
    nb = "tests/usr.bin/basename/t_basename.sh"
    for i, (arg, result) in enumerate([("/usr/bin", "bin"), ("/usr", "usr"), ("/", "/"),
                                      ("///", "/"), ("/usr//", "usr"),
                                      ("//usr//bin", "bin"), ("usr", "usr"), ("usr/bin", "bin")]):
        add("netbsd", "basename", f"basic-{i}", [arg], expected=(result+"\n").encode(),
            source=nb, marker="basic_body()")
    for i, (args, result) in enumerate([(["/usr/bin", "n"], "bi"),
                                        (["/usr/bin", "bin"], "bin"),
                                        (["/", "/"], "/"),
                                        (["/usr/bin/gcc", "cc"], "g")]):
        add("netbsd", "basename", f"suffix-{i}", args, expected=(result+"\n").encode(),
            source=nb, marker="suffix_body()")
    nd = "tests/usr.bin/dirname/t_dirname.sh"
    for i, (arg, result) in enumerate([("/", "/"), ("//", "/"),
                                      ("/usr/bin/", "/usr"), ("//usr//bin//", "//usr"),
                                      ("usr", "."), ("", "."), ("/usr", "/"),
                                      ("/usr/bin", "/usr"), ("usr/bin", "usr")]):
        add("netbsd", "dirname", f"basic-{i}", [arg], expected=(result+"\n").encode(),
            source=nd, marker="basic_body()")
    for name, opts, asset in [("align", ["-be"], "d_align"),
                               ("se-output", ["-se"], "d_se_output")]:
        base = "tests/bin/cat/"
        add("netbsd", "cat", name, [*opts, "input"],
            files=[("input", (sources/"netbsd"/(base+asset+".in")).read_bytes())],
            expected=(sources/"netbsd"/(base+asset+".out")).read_bytes(),
            source=base+"t_cat.sh", marker=asset+".out")
    fs = "usr.bin/seq/tests/seq_test.sh"
    add("freebsd", "seq", "float-rounding", ["1", "0.1", "1.2"],
        expected=b"1\n1.1\n1.2\n", source=fs, marker="float_rounding_body()")
    fh = "usr.bin/head/tests/head_test.sh"
    add("freebsd", "head", "empty-file", ["input"], files=[("input", b"")],
        expected=b"", source=fh, marker="empty_file_body()")
    add("freebsd", "head", "default-ten-lines", ["input"],
        files=[("input", b"test\n"*100)], expected=b"test\n"*10,
        source=fh, marker="default_no_options_body()")
    add("freebsd", "head", "line-count-fifty", ["-n", "50", "input"],
        files=[("input", b"test\n"*100)], expected=b"test\n"*50,
        source=fh, marker="line_count_body()")
    add("freebsd", "head", "byte-count-fifty", ["-c", "50", "input"],
        files=[("input", b"test\n"*100)], expected=b"test\n"*10,
        source=fh, marker="byte_count_body()")
    add("freebsd", "head", "stdin-default", stdin=b"test\n"*20,
        expected=b"test\n"*10, source=fh, marker="read_from_stdin_body()")
    add("freebsd", "head", "silent-header", ["-q", "first", "second"],
        files=[("first", b"1\n"*11), ("second", b"2\n"*11)],
        expected=b"1\n"*10+b"2\n"*10,
        source=fh, marker="silent_header_body()")
    add("freebsd", "head", "verbose-header", ["-v", "file1"],
        files=[("file1", b"test\n"*10)],
        expected=b"==> file1 <==\n"+b"test\n"*10,
        source=fh, marker="verbose_header_body()")
    ft = "usr.bin/tail/tests/tail_test.sh"
    for i, (args, result) in enumerate([(["-1", "input"], b"c"),
                                        (["-2", "input"], b"b\nc"),
                                        (["-3", "input"], b"a\nb\nc"),
                                        (["-4", "input"], b"a\nb\nc")]):
        add("freebsd", "tail", f"no-lf-{i}", args, files=[("input", b"a\nb\nc")],
            expected=result, source=ft, marker="no_lf_at_eof_body()")
    from basic_cases import basic_cases
    from family_cases import family_cases
    from implemented_cases import implemented_cases
    out.extend(family_cases())
    out.extend(implemented_cases())
    tracked = tracked_utilities()
    return permute_locales(out + basic_cases(tracked - {case.util for case in out}), locales)


def run_cases(binary: Path, selected: list[Case], sources: Path) -> tuple[int, int]:
    errors: list[str] = []
    counts: dict[tuple[str, str], list[int]] = {}
    for case in selected:
        key = (case.family, case.locale)
        counts.setdefault(key, [0, 0])[1] += 1
        label = f"{case.family}/{case.util}/{case.name} [{case.locale}]"
        if case.source:
            source = sources/case.family/case.source
            if not source.is_file() or case.marker not in source.read_text():
                raise RuntimeError(f"{label}: "
                                   "upstream source marker missing")
        reference_elapsed: list[float] = []
        try:
            if case.expected is None:
                expected = execute(reference_command(case.reference or case.family, case.util),
                                   case, elapsed_out=reference_elapsed)
            else:
                expected = (0, case.expected, b"", fixture_snapshot(case))
        except (OSError, RuntimeError) as exc:
            raise RuntimeError(f"{label}: "
                               f"invalid reference: {exc}") from exc
        if reference_elapsed and (problem := duration_error(case, reference_elapsed[0])):
            raise RuntimeError(f"{label}: "
                               f"invalid reference: {problem}")
        try:
            actual_elapsed: list[float] = []
            actual = execute([str(binary), case.util], case, elapsed_out=actual_elapsed)
            problems = []
            if actual != expected:
                problems.append(describe_difference(expected, actual))
            if problem := duration_error(case, actual_elapsed[0]):
                problems.append(problem)
            if problems:
                errors.append(f"{label}: " + "; ".join(problems))
            else:
                counts[key][0] += 1
        except (OSError, RuntimeError) as exc:
            errors.append(f"{label}: {exc}")
    for (family, locale), (passed, total) in counts.items():
        print(f"{family} [{locale}] corpus: {passed}/{total} cases passed")
    for error in errors[:30]:
        print(error[:500])
    if len(errors) > 30:
        print(f"... {len(errors)-30} more failures omitted")
    return len(errors), len(selected)
