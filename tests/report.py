#!/usr/bin/env python3
"""Generate a complete per-project utility status table from current conformance tests."""

import argparse
from collections import defaultdict
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timezone
import io
import json
import os
from pathlib import Path
import re
import subprocess

from conformance import GNU_SCRIPTS, run_gnu
from corpus import Case, cases, duration_error, validate_coverage
from family_cases import family_cases
from implemented_cases import implemented_cases
from reference import execute, fixture_snapshot, reference_command

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
SOURCES = Path(os.environ.get("LUTILS_TEST_SOURCES", "/nonexistent/lutils-test-sources"))
FAMILIES = ("gnu", "uutils", "netbsd", "freebsd", "behavior", "basic", "imported", "suite")
ROW = re.compile(r"^\| ([^|]+) \| `([^`]+)` \| (Yes|No) \| ([^|]+) \|$")


def check_case(case: Case, binary: Path) -> bool:
    if case.source:
        source = SOURCES / case.family / case.source
        if not source.is_file() or case.marker not in source.read_text():
            raise RuntimeError(f"{case.family}/{case.util}/{case.name}: "
                               "upstream source marker missing")
    reference_elapsed: list[float] = []
    if case.expected is None:
        expected = execute(reference_command(case.reference or case.family, case.util),
                           case, elapsed_out=reference_elapsed)
    else:
        expected = (0, case.expected, b"", fixture_snapshot(case))
    if reference_elapsed and (problem := duration_error(case, reference_elapsed[0])):
        raise RuntimeError(f"{case.family}/{case.util}/{case.name}: "
                           f"invalid reference: {problem}")
    try:
        actual_elapsed: list[float] = []
        actual = execute([str(binary), case.util], case, elapsed_out=actual_elapsed)
        return actual == expected and duration_error(case, actual_elapsed[0]) is None
    except (OSError, RuntimeError):
        return False


def imported_cases() -> list[tuple[Case, str, str]]:
    records = json.loads((HERE / "uutils_cases.json").read_text())
    output = []
    for index, record in enumerate(records):
        source_file, test_name = record["source"].split("::", 1)
        case = Case("uutils", record["util"], f"imported-{index}",
                    args=tuple(record["args"]), expected=record["stdout"].encode())
        output.append((case, source_file, test_name.split("::", 1)[0]))
    return output


def tally(binary: Path) -> tuple[dict, dict[str, int], dict[str, list[int]]]:
    counts = defaultdict(lambda: defaultdict(lambda: [0, 0]))
    suite_cases: dict[str, int] = {}
    locale_counts: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for case in cases(SOURCES):
        passed = check_case(case, binary)
        count = counts[case.util][case.family]
        count[0] += int(passed)
        count[1] += 1
        locale_counts[case.locale][0] += int(passed)
        locale_counts[case.locale][1] += 1
    for case, source_file, marker in imported_cases():
        source = SOURCES / "uutils/tests/by-util" / source_file
        if not source.is_file() or marker not in source.read_text():
            raise RuntimeError(f"imported uutils source marker missing: {source_file}::{marker}")
        passed = check_case(case, binary)
        count = counts[case.util]["imported"]
        count[0] += int(passed)
        count[1] += 1
    for util in GNU_SCRIPTS:
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            failures, _ = run_gnu(binary, {util}, suite_cases)
        counts[util]["suite"][0] += int(failures == 0)
        counts[util]["suite"][1] += 1
    return counts, suite_cases, locale_counts


def render(counts: dict, suite_cases: dict[str, int],
           locale_counts: dict[str, list[int]]) -> str:
    rows = []
    for line in (ROOT / "README.md").read_text().splitlines():
        match = ROW.match(line)
        if match:
            rows.append(match.groups()[:3])
    if not rows:
        raise RuntimeError("no utility rows found in README.md")
    tracked_lines = [line for line in (ROOT / "README.md").read_text().splitlines()
                     if line.startswith("| ") and " | `" in line]
    if len(rows) != len(tracked_lines):
        raise RuntimeError("README utility table has a row that report.py cannot parse")
    totals = [0, 0]
    for util in counts:
        for passed, total in counts[util].values():
            totals[0] += passed
            totals[1] += total
    unique = {util for _, util, _ in rows}
    if counts.keys() - unique:
        raise RuntimeError(f"tested utilities missing from README: {sorted(counts.keys() - unique)}")
    tested = unique & counts.keys()
    implemented = {util for _, util, status in rows if status == "Yes"}
    top = sorted(((util, sum(p for p, _ in counts[util].values()))
                  for util in tested), key=lambda item: item[1], reverse=True)[:8]
    top_passes = sum(value for _, value in top)
    all_cases = cases(SOURCES)
    unique_shapes = len({(case.util, case.locale, case.args, case.stdin,
                          case.files, case.dirs, case.links, case.output_limit,
                          case.min_runtime, case.max_runtime)
                         for case in all_cases})
    case_key = lambda case: (case.util, case.locale, case.args, case.stdin,
                             case.files, case.dirs, case.links, case.output_limit,
                             case.min_runtime, case.max_runtime)
    gnu_cases = {case_key(case): case for case in all_cases if case.family == "gnu"}
    uutils_cases = {case_key(case): case for case in all_cases if case.family == "uutils"}
    shared = gnu_cases.keys() & uutils_cases.keys()
    disagreements = []
    for key in shared:
        gnu_case, uutils_case = gnu_cases[key], uutils_cases[key]
        gnu_result = execute(reference_command("gnu", gnu_case.util), gnu_case)
        uutils_result = execute(reference_command("uutils", uutils_case.util), uutils_case)
        if gnu_result != uutils_result:
            disagreements.append((gnu_case.util, gnu_case.name, gnu_case.locale))
    disagreements.sort()
    agreement = len(shared) - len(disagreements)
    concentration = (f"The expanded corpus has {len(all_cases)} executions but only "
                     f"{unique_shapes} distinct test configurations after collapsing source-family "
             "duplicates while retaining locale variants. The eight utilities with the "
             "most passing checks "
                     f"account for {top_passes}/{totals[0]} passes: " +
                     ", ".join(f"`{util}` ({value})" for util, value in top) + ".")
    deep = implemented_cases() + family_cases()
    deep_utils = {case.util for case in deep}
    basic_only = {util for util in unique
                  if {case.family for case in all_cases if case.util == util} == {"basic"}}
    lines = ["# Utility test status", "",
             f"Generated {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')} "
             "with `nix develop --command python3 tests/report.py --output tests/STATUS.md`.", "",
             f"**{totals[0]}/{totals[1]} checks pass.** "
             f"Coverage: {len(tested)}/{len(unique)} distinct utilities have tests; "
             f"{len(implemented & tested)}/{len(implemented)} implemented utilities "
             "have tests. The table includes all "
             f"{len(rows)} project and utility rows tracked in the README.", "",
             concentration, "",
             "Reference-backed corpus cases run under both C and C.UTF-8. "
             "Literal expectations, imported uutils cases, and GNU Perl suites "
             "run in C.", "",
             "Corpus checks by locale: " + ", ".join(
                 f"`{locale}` {passed}/{total}"
                 for locale, (passed, total) in sorted(locale_counts.items())) + ".", "",
             f"GNU and uutils agree on {agreement}/{len(shared)} shared corpus inputs. "
             "This is reference agreement, not `lutils` conformance.", "",
             ("Reference disagreements: " + ", ".join(f"`{util}/{name}` [{locale}]"
               for util, name, locale in disagreements) + "." if disagreements else
              "No GNU/uutils reference disagreements were observed."), "",
             f"The four GNU Perl suites executed {sum(suite_cases.values())} named "
             "subcases (" + ", ".join(f"`{util}` {count}" for util, count in suite_cases.items()) +
             "). They count as four suite checks in the headline.", "",
             f"Curated behavioral cases add {len(deep)} executions across "
             f"{len(deep_utils)} utilities. {len(basic_only)} utilities still have "
             "only a baseline case; these rows indicate test reach, not deep "
             "conformance. Privileged and interactive commands need isolated "
             "system fixtures before positive paths can be checked.", "",
             "Each cell is passed/total. `—` means no test in that source. "
             "An imported check is a ported uutils case; a GNU suite counts as one "
             "suite check. The same utility appears in multiple project rows with "
             "the same test counts; the headline counts each check once. "
             "Failures from stubs are expected.", "",
             "| Project | Utility | Implemented | GNU | uutils | NetBSD | FreeBSD | Behavior | Basic | Imported | GNU suite | Total | Result |",
             "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
    for project, util, implemented in rows:
        per_family = counts.get(util, {})
        values = []
        passed = total = 0
        for family in FAMILIES:
            p, n = per_family.get(family, (0, 0))
            passed += p
            total += n
            values.append(f"{p}/{n}" if n else "—")
        result = "Untested" if total == 0 else "Passing" if passed == total else "Failing"
        lines.append(f"| {project} | `{util}` | {implemented} | " +
                     " | ".join(values) + f" | {passed}/{total} | {result} |"
                     if total else f"| {project} | `{util}` | {implemented} | " +
                     " | ".join(values) + " | — | Untested |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, default=ROOT / ".lake/build/bin/lutils")
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not SOURCES.is_dir():
        parser.error("run inside `nix develop`")
    if not args.no_build:
        subprocess.run(["lake", "build", "lutils"], cwd=ROOT, check=True)
    binary = args.bin.resolve()
    if not binary.is_file():
        parser.error(f"binary does not exist: {binary}")
    validate_coverage(binary, cases(SOURCES))
    counts, suite_cases, locale_counts = tally(binary)
    report = render(counts, suite_cases, locale_counts)
    if args.output:
        args.output.write_text(report)
        print(f"wrote {args.output}")
    else:
        print(report, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
