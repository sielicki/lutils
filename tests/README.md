# Conformance and performance testing

Run the test environment and the conformance runner:

```sh
nix develop --command python3 tests/conformance.py
```

The runner builds `lutils`, runs four original GNU Perl suites and 41 cases
ported from uutils Rust tests, then compares a reference-backed corpus against
GNU, uutils, and other utility families. It also runs literal cases and
fixture files from NetBSD and FreeBSD tests. A nonzero exit is expected while
applets are incomplete; the summary reports passing and failing cases by
source. Use `--source gnu`, `uutils`, `netbsd`, `freebsd`, `behavior`, or `basic`
and repeat `--util NAME` to narrow the run.
Reference-backed corpus cases run under both `C` and `C.UTF-8` by default;
each run compares the reference and `lutils` in the same locale. Repeat
`--locale NAME` to choose the locales to exercise. Literal upstream
expectations, ported uutils cases, and GNU Perl suites run in `C`.
`--source legacy` runs only the original GNU suites and uutils cases.
`--no-build` uses an existing binary.

[`basic_cases.py`](basic_cases.py) supplies a baseline case for every utility
without another corpus case. These use safe stdin transforms, temporary file
operations, read-only commands, or utility-specific argument validation.
[`implemented_cases.py`](implemented_cases.py) adds harder cases for implemented
applets, including recursive file operations, symlinks, and stream boundaries.
[`family_cases.py`](family_cases.py) exercises findutils, diffutils, sed, tar,
ACLs, and selected util-linux and procps behavior. The latter cases run with
`--source behavior`. References for these families come from the Nix shell.
Adding a utility to the README without a case raises an error when loading the
corpus.
The runner also compares the README and corpus with `lutils --list`, so an
untracked applet fails the coverage check.
The cases are expected to fail for stubs. Privileged and interactive commands
currently have safe baseline checks; positive conformance for those commands
needs an isolated system fixture.

Generate the full per-project status table with
`nix develop --command python3 tests/report.py --output tests/STATUS.md`.
The [current report](STATUS.md) includes every utility row from the project
README, including untested stubs. The headline check count is an execution
count, not a compatibility percentage: GNU and uutils repeat many inputs, and
each GNU Perl suite counts as one check despite containing many assertions.

The [Nix test source definition](../nix/test-sources.nix) pins upstream files
by commit and hash and supplies them through `LUTILS_TEST_SOURCES`. The original
GNU Perl files run from that store path. The runner checks each ported uutils
and BSD case against its pinned source file. [`corpus.py`](corpus.py) assembles
all cases: each records the source family, applet, arguments, input bytes, and
filesystem fixtures. Reference cases compare exit status, stdout, stderr, and
the resulting file tree, including types, permissions, ownership, hard links,
symlinks, POSIX ACLs, and bytes. Runs use fresh temporary directories. Timeouts
fail rather than count as matching results; reference failures abort the run so
they cannot be reported as `lutils` failures. `sleep` and `timeout` cases also
check the child process elapsed time. BSD cases compare against
expectations from their source scripts. Reference binaries and upstream source
files are provided by Nix; upstream copies are not committed to this repository.

Run seeded differential mutation in the Nix shell:

```sh
nix develop --command python3 tests/differential.py --seed 42 --iterations 100 --save-dir /tmp/lutils-repros
nix develop --command python3 tests/differential.py --replay /tmp/lutils-repros/seed-42-case-10-cat.json
```

The runner mutates bounded arguments, stdin, or file contents from safe corpus
seeds. It compares GNU and uutils first; only cases where those references agree
are judged against `lutils`. The report separates reference disagreements from
`lutils` mismatches. Saved JSON contains the complete input bytes and can be
replayed even if generation changes, including the locale used. `--util NAME`
and `--locale NAME` narrow the seed selection; `--seed` makes the run
reproducible. This is a deterministic mutation runner,
not coverage-guided libFuzzer instrumentation.

Check the harness itself with `python3 -m unittest discover -s tests -p 'test_*.py'`.

Run performance comparisons in the same shell:

```sh
nix develop --command uv run tests/performance.py
```

The benchmark checks every warmup and measured output against GNU, including
the copied file for `cp`; invalid runs have no timing result. It rotates command
order to reduce cache bias, then reports median process time, median absolute
deviation, and effective workload MiB/s in a GitHub Markdown table. The script
uses inline `uv` metadata to install pandas and tabulate. The rate is
based on fixture or result size, not measured disk I/O. There is no performance
pass threshold. Use `--repeats` and `--size-mib` to change the sample count and
stream size; `--json-output PATH` saves raw samples and validation results.
Results include process startup and depend on the machine and Nix package
versions.
