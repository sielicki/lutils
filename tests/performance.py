#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pandas>=2.2,<4", "tabulate>=0.9,<1"]
# ///
"""Benchmark validated lutils, GNU, and uutils workloads."""

import argparse
import base64
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
MIB = 1024 * 1024


@dataclass(frozen=True)
class Scenario:
    name: str
    utility: str
    args: tuple[str, ...]
    input_file: bool = False
    output_file: bool = False
    rate_basis: str | None = None
    input_encoding: str | None = None


@dataclass(frozen=True)
class Observation:
    status: int
    stderr: bytes
    stdout: tuple[int, str] | None
    output: tuple[int, str] | None
    elapsed_ms: float


def fingerprint(path: Path) -> tuple[int, str] | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(MIB), b""):
            digest.update(chunk)
            size += len(chunk)
    return size, digest.hexdigest()


def make_input(path: Path, size_mib: int) -> None:
    # Keep even large fixture generation outside timed samples.
    chunk = (b"alpha beta gamma\n" * (MIB // 17 + 1))[:MIB]
    with path.open("wb") as stream:
        for _ in range(size_mib):
            stream.write(chunk)


def make_comm_inputs(work: Path, size_mib: int) -> None:
    """Two interleaved sorted files, with about size_mib MiB of total input."""
    records = max(1, size_mib * MIB // 20)
    with (work / "left").open("wb") as left, (work / "right").open("wb") as right:
        for start in range(0, records, 4096):
            end = min(records, start + 4096)
            left.write(b"".join(f"{2 * i:09d}\n".encode() for i in range(start, end)))
            right.write(b"".join(f"{2 * i + 1:09d}\n".encode() for i in range(start, end)))


def run_one(command: list[str], scenario: Scenario, work: Path,
            environment: dict[str, str]) -> Observation:
    stdout_path = work / "stdout"
    output_path = work / "output"
    output_path.unlink(missing_ok=True)
    # Prepare the sink before starting the clock. The child writes into it.
    with stdout_path.open("wb") as stdout:
        start = time.perf_counter_ns()
        result = subprocess.run(
            [*command, *scenario.args], cwd=work, stdin=subprocess.DEVNULL,
            stdout=stdout, stderr=subprocess.PIPE, env=environment, timeout=30,
            check=False,
        )
        elapsed_ms = (time.perf_counter_ns() - start) / 1_000_000
    return Observation(result.returncode, result.stderr, fingerprint(stdout_path),
                       fingerprint(output_path) if scenario.output_file else None,
                       elapsed_ms)


def validate(actual: Observation, expected: Observation, scenario: Scenario) -> str | None:
    if actual.status != expected.status:
        return f"exit {actual.status}, expected {expected.status}"
    if actual.stderr != expected.stderr:
        return f"stderr {actual.stderr[:100]!r}, expected {expected.stderr[:100]!r}"
    if actual.stdout != expected.stdout:
        got = "missing" if actual.stdout is None else f"{actual.stdout[0]} bytes"
        want = "missing" if expected.stdout is None else f"{expected.stdout[0]} bytes"
        return f"stdout differs (got {got}, expected {want})"
    if scenario.output_file and actual.output != expected.output:
        got = "missing" if actual.output is None else f"{actual.output[0]} bytes"
        want = "missing" if expected.output is None else f"{expected.output[0]} bytes"
        return f"copied file differs (got {got}, expected {want})"
    return None


def scenarios(size_mib: int) -> list[Scenario]:
    half = max(1, size_mib * MIB // 2)
    return [
        Scenario("cat file", "cat", ("input",), input_file=True, rate_basis="stdout"),
        Scenario("head 100 lines", "head", ("-n", "100", "input"), input_file=True),
        Scenario("head half bytes", "head", ("-c", str(half), "input"),
                 input_file=True, rate_basis="stdout"),
        Scenario("tail 100 lines", "tail", ("-n", "100", "input"),
                 input_file=True, rate_basis="logical input"),
        Scenario("wc lines", "wc", ("-l", "input"),
                 input_file=True, rate_basis="logical input"),
        Scenario("wc words", "wc", ("-w", "input"),
                 input_file=True, rate_basis="logical input"),
        Scenario("comm merge", "comm", ("left", "right"), rate_basis="comm input"),
        Scenario("paste parallel", "paste", ("input", "input"),
                 input_file=True, rate_basis="stdout"),
        Scenario("paste serial", "paste", ("-s", "input"),
                 input_file=True, rate_basis="logical input"),
        Scenario("expand plain", "expand", ("-t4", "input"),
                 input_file=True, rate_basis="logical input"),
        Scenario("grep fixed", "grep", ("-F", "beta", "input"),
                 input_file=True, rate_basis="logical input"),
        Scenario("sha224sum file", "sha224sum", ("input",),
                 input_file=True, rate_basis="logical input"),
        Scenario("sha256sum file", "sha256sum", ("input",),
                 input_file=True, rate_basis="logical input"),
        Scenario("base64 file", "base64", ("input",),
                 input_file=True, rate_basis="logical input"),
        Scenario("base32 file", "base32", ("input",),
                 input_file=True, rate_basis="logical input"),
        Scenario("basenc base64", "basenc", ("--base64", "input"),
                 input_file=True, rate_basis="logical input"),
        Scenario("base64 decode", "base64", ("-d", "input"),
                 input_file=True, rate_basis="logical input", input_encoding="base64"),
        Scenario("base32 decode", "base32", ("-d", "input"),
                 input_file=True, rate_basis="logical input", input_encoding="base32"),
        Scenario("basenc decode", "basenc", ("--base64", "-d", "input"),
                 input_file=True, rate_basis="logical input", input_encoding="base64"),
        Scenario("cp file", "cp", ("input", "output"),
                 input_file=True, output_file=True, rate_basis="copy"),
        Scenario("seq 10000", "seq", ("10000",)),
        Scenario("basename", "basename", ("/usr/local/share/example.txt",)),
    ]


def summary_row(record: dict) -> dict[str, str]:
    results = record["implementations"]
    def timing(label: str) -> str:
        if label not in results:
            return "N/A"
        median = results[label]["median_ms"]
        deviation = results[label]["mad_ms"]
        return f"{median:.2f} ± {deviation:.2f}" if median is not None else "INVALID"

    def rate(label: str) -> str:
        value = results[label]["effective_mib_s"] if label in results else None
        return f"{value:.1f}" if value is not None else "—"

    lutils_ms = results["lutils"]["median_ms"]
    gnu_ms = results["GNU"]["median_ms"]
    return {
        "Scenario": record["name"],
        "lutils ms": timing("lutils"),
        "GNU ms": timing("GNU"),
        "uutils ms": timing("uutils"),
        "lutils/GNU": f"{lutils_ms / gnu_ms:.2f}×" if lutils_ms is not None and gnu_ms else "—",
        "L MiB/s": rate("lutils"),
        "GNU MiB/s": rate("GNU"),
        "U MiB/s": rate("uutils"),
    }


def markdown_table(records: list[dict]) -> str:
    # Import only when rendering, so the stdlib benchmark tests remain usable
    # without installing the script's display dependencies.
    import pandas as pd

    return pd.DataFrame([summary_row(record) for record in records]).to_markdown(
        index=False, tablefmt="github", disable_numparse=True,
    )


def benchmark(scenario: Scenario, commands: dict[str, list[str]], repeats: int,
              size_mib: int, environment: dict[str, str]) -> dict:
    labels = list(commands)
    with tempfile.TemporaryDirectory(prefix="lutils-perf-") as tmp:
        work = Path(tmp)
        if scenario.rate_basis == "comm input":
            make_comm_inputs(work, size_mib)
        if scenario.input_file:
            make_input(work / "input", size_mib)
            if scenario.input_encoding:
                plain = (work / "input").read_bytes()
                encoded = (base64.b64encode(plain) if scenario.input_encoding == "base64"
                           else base64.b32encode(plain))
                (work / "input").write_bytes(encoded)
        expected = run_one(commands["GNU"], scenario, work, environment)
        if expected.status != 0 or expected.stderr:
            raise RuntimeError(f"GNU reference failed: exit {expected.status}, "
                               f"stderr {expected.stderr[:100]!r}")
        if (expected.stdout is None or expected.stdout[0] == 0) and not scenario.output_file:
            raise RuntimeError("GNU reference produced no stdout")
        if scenario.output_file and expected.output is None:
            raise RuntimeError("GNU reference created no output file")
        if scenario.rate_basis == "stdout":
            work_bytes = expected.stdout[0] if expected.stdout else 0
        elif scenario.rate_basis == "copy":
            work_bytes = expected.output[0] if expected.output else 0
        elif scenario.rate_basis == "logical input":
            work_bytes = (work / "input").stat().st_size
        elif scenario.rate_basis == "comm input":
            work_bytes = (work / "left").stat().st_size + (work / "right").stat().st_size
        else:
            work_bytes = 0

        results = {label: {"samples_ms": [], "error": None} for label in labels}
        # One warmup round, then rotate the order to balance cache effects.
        for round_number in range(repeats + 1):
            order = labels[round_number % len(labels):] + labels[:round_number % len(labels)]
            for label in order:
                if results[label]["error"] is not None:
                    continue
                try:
                    actual = run_one(commands[label], scenario, work, environment)
                except (OSError, subprocess.TimeoutExpired) as exc:
                    results[label]["error"] = str(exc)
                    continue
                error = validate(actual, expected, scenario)
                if error is not None:
                    results[label]["error"] = error
                elif round_number > 0:
                    results[label]["samples_ms"].append(actual.elapsed_ms)
        for result in results.values():
            samples = result["samples_ms"]
            median = statistics.median(samples) if len(samples) == repeats else None
            result["median_ms"] = median
            result["mad_ms"] = (statistics.median(abs(sample - median) for sample in samples)
                                if median is not None else None)
            result["effective_mib_s"] = (work_bytes / MIB / (median / 1000)
                                         if median is not None and median > 0 and work_bytes else None)
        return {
            "name": scenario.name, "utility": scenario.utility,
            "args": list(scenario.args),
            "input_bytes": work_bytes if scenario.rate_basis == "comm input" else
                (work / "input").stat().st_size if scenario.input_file else 0,
            "work_bytes": work_bytes, "rate_basis": scenario.rate_basis,
            "implementations": results,
        }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, default=ROOT / ".lake/build/bin/lutils")
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--size-mib", type=int, default=2)
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--json-output", type=Path, help="write raw samples and validation results")
    args = parser.parse_args()
    if args.repeats < 1 or args.size_mib < 1:
        parser.error("repeats and size-mib must be positive")
    if not args.no_build:
        subprocess.run(["lake", "build", "lutils"], cwd=ROOT, check=True)
    binary = args.bin.resolve()
    if not binary.is_file():
        parser.error(f"binary does not exist: {binary}")
    gnu = os.environ.get("LUTILS_GNU_BIN")
    uutils = os.environ.get("LUTILS_UUTILS_BIN")
    if not gnu or not uutils:
        parser.error("run inside `nix develop` for GNU and uutils reference binaries")
    environment = {**os.environ, "LC_ALL": "C"}
    records = []
    failed = False
    errors = []
    for scenario in scenarios(args.size_mib):
        gnu_directory = os.environ.get("LUTILS_GREP_BIN") if scenario.utility == "grep" else gnu
        commands = {
            "lutils": [str(binary), scenario.utility],
            "GNU": [str(Path(gnu_directory) / scenario.utility)],
        }
        if scenario.utility != "grep":
            commands["uutils"] = [str(Path(uutils) / f"uutils-{scenario.utility}")]
        try:
            record = benchmark(scenario, commands, args.repeats, args.size_mib, environment)
        except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
            errors.append(f"{scenario.name}: INVALID: {exc}")
            failed = True
            continue
        records.append(record)
        results = record["implementations"]
        for label, result in results.items():
            if result["error"] is not None:
                errors.append(f"{scenario.name} / {label}: INVALID: {result['error']}")
                failed = True
    print("Process time in ms: median ± median absolute deviation; every output checked against GNU.\n")
    print("Effective MiB/s uses output/copy bytes or logical input size; it does not measure disk I/O.\n")
    if records:
        print(markdown_table(records))
    if errors:
        print("\nValidation errors:\n")
        for error in errors:
            print(f"- {error}")
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps({
            "lutils_binary": str(binary), "gnu_bin": gnu, "uutils_bin": uutils,
            "repeats": args.repeats, "size_mib": args.size_mib, "scenarios": records,
        }, indent=2) + "\n")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
