#!/usr/bin/env python3
"""Run imported GNU tests and uutils cases against the Lean multicall binary."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from corpus import DEFAULT_LOCALES, cases as corpus_cases, validate_coverage


ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
SOURCES = Path(os.environ["LUTILS_TEST_SOURCES"]) if "LUTILS_TEST_SOURCES" in os.environ else Path("/nonexistent/lutils-test-sources")
GNU = SOURCES / "gnu"
UUTILS = SOURCES / "uutils"
GNU_SCRIPTS = {
    "basename": "misc/basename.pl",
    "dirname": "misc/dirname.pl",
    "head": "head/head.pl",
    "seq": "seq/seq.pl",
}


def run_uutils(binary: Path, selected: set[str] | None) -> tuple[int, int]:
    cases = json.loads((HERE / "uutils_cases.json").read_text())
    cases = [c for c in cases if selected is None or c["util"] in selected]
    failures = 0
    for case in cases:
        source_file, source_test = case["source"].split("::", 1)
        source = UUTILS / "tests" / "by-util" / source_file
        if not source.is_file() or source_test.split("::")[0] not in source.read_text():
            print(f"uutils {case['source']}: missing upstream source", file=sys.stderr)
            failures += 1
            continue
        result = subprocess.run(
            [str(binary), case["util"], *case["args"]],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=10, env={**os.environ, "LC_ALL": "C"},
        )
        expected = case["stdout"].encode()
        if result.returncode != 0 or result.stdout != expected or result.stderr:
            failures += 1
            print(f"uutils {case['source']} {case['util']} {case['args']!r}: FAIL")
            print(f"  expected: exit 0, stdout {expected!r}, stderr b''")
            print(f"  actual:   exit {result.returncode}, stdout {result.stdout!r}, stderr {result.stderr!r}")
    print(f"uutils: {len(cases) - failures}/{len(cases)} cases passed")
    return failures, len(cases)


def run_gnu(binary: Path, selected: set[str] | None,
            case_counts: dict[str, int] | None = None) -> tuple[int, int]:
    utils = [u for u in GNU_SCRIPTS if selected is None or u in selected]
    failures = 0
    with tempfile.TemporaryDirectory(prefix="lutils-gnu-") as temporary:
        work = Path(temporary)
        bindir = work / "bin"
        bindir.mkdir()
        for util in utils:
            (bindir / util).symlink_to(binary)
        env = {**os.environ,
               "PATH": f"{bindir}{os.pathsep}{os.environ.get('PATH', '')}",
               "PERL5LIB": str(GNU / "tests"),
               "PERL5OPT": "-MCuSkip -MCoreutils",
               "built_programs": " ".join(utils),
               "srcdir": str(GNU),
               "LC_ALL": "C"}
        if case_counts is not None:
            env["VERBOSE"] = "1"
        for util in utils:
            script = GNU / "tests" / GNU_SCRIPTS[util]
            result = subprocess.run(["perl", str(script)], cwd=work, env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    text=True, timeout=30)
            if case_counts is not None:
                case_counts[util] = sum(line.endswith("...") for line in result.stderr.splitlines())
            print(f"GNU {script.relative_to(GNU)}: {'PASS' if result.returncode == 0 else 'FAIL'}")
            if result.returncode != 0:
                failures += 1
                print(result.stdout + result.stderr, end="", file=sys.stderr)
    print(f"GNU: {len(utils) - failures}/{len(utils)} suites passed")
    return failures, len(utils)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=("all", "gnu", "uutils", "netbsd", "freebsd", "behavior", "basic", "legacy"), default="all")
    parser.add_argument("--util", action="append", help="limit to an applet; may be repeated")
    parser.add_argument("--locale", action="append", help="locale for reference-backed cases; repeat to permute (default: C and C.UTF-8)")
    parser.add_argument("--bin", type=Path, default=ROOT / ".lake/build/bin/lutils")
    parser.add_argument("--no-build", action="store_true", help="use an existing binary")
    args = parser.parse_args()
    if not SOURCES.is_dir():
        parser.error("run inside `nix develop` so LUTILS_TEST_SOURCES is available")
    if not args.no_build and args.bin == ROOT / ".lake/build/bin/lutils":
        subprocess.run(["lake", "build", "lutils"], cwd=ROOT, check=True)
    binary = args.bin.resolve()
    if not binary.is_file():
        parser.error(f"binary does not exist: {binary}")
    selected = set(args.util) if args.util else None
    corpus = corpus_cases(SOURCES, locales=tuple(args.locale or DEFAULT_LOCALES))
    validate_coverage(binary, corpus)
    known = set(GNU_SCRIPTS) | {c["util"] for c in json.loads((HERE / "uutils_cases.json").read_text())} | {c.util for c in corpus}
    if selected and selected - known:
        parser.error(f"unknown applet(s): {', '.join(sorted(selected - known))}")
    failures = total = 0
    if args.source in ("all", "uutils", "legacy"):
        if selected is None or selected & {c["util"] for c in json.loads((HERE / "uutils_cases.json").read_text())}:
            f, n = run_uutils(binary, selected)
            failures += f
            total += n
    if args.source in ("all", "gnu", "legacy"):
        if shutil.which("perl") is None:
            parser.error("GNU suites require Perl")
        if selected is None or selected & set(GNU_SCRIPTS):
            f, n = run_gnu(binary, selected)
            failures += f
            total += n
    if args.source != "legacy":
        from corpus import run_cases
        chosen = [c for c in corpus if (selected is None or c.util in selected)
                  and (args.source == "all" or c.family == args.source)]
        f, n = run_cases(binary, chosen, SOURCES)
        failures += f
        total += n
    if total == 0:
        parser.error("selection contains no cases")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
