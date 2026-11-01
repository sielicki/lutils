#!/usr/bin/env python3
"""Seeded differential mutation of safe utility inputs against GNU and uutils."""

import argparse
import base64
from dataclasses import replace
import json
import os
from pathlib import Path
import random
import subprocess
import sys

from corpus import Case, cases
from reference import ExecutionTimeout, describe_difference, execute, reference_command

ROOT = Path(__file__).resolve().parents[1]
SOURCES = Path(os.environ.get("LUTILS_TEST_SOURCES", "/nonexistent/lutils-test-sources"))
UTILS = {"basename", "dirname", "echo", "cat", "head", "tail", "wc",
         "cut", "tr", "sort", "uniq", "tac", "base32", "base64", "basenc",
         "md5sum", "sha224sum", "sha256sum", "cksum"}
ALPHABET = b"abcXYZ019/._- \n\t\x00\xff\x80\\"


def mutate_bytes(data: bytes, rng: random.Random) -> bytes:
    data = data[:256]
    for _ in range(rng.randint(1, 4)):
        index = rng.randrange(len(data) + 1)
        operation = rng.choice(("insert", "replace", "delete", "duplicate"))
        if operation == "insert":
            data = data[:index] + bytes([rng.choice(ALPHABET)]) + data[index:]
        elif operation == "replace" and index < len(data):
            data = data[:index] + bytes([rng.choice(ALPHABET)]) + data[index+1:]
        elif operation == "delete" and index < len(data):
            data = data[:index] + data[index+1:]
        elif operation == "duplicate" and index < len(data):
            data = data[:index] + data[index:index+min(rng.randint(1, 8), len(data)-index)] + data[index:]
    return data[:256]


def mutate(seed: Case, rng: random.Random) -> Case:
    if seed.util in ("basename", "dirname", "echo"):
        args = list(seed.args)
        if seed.util == "echo" and not args:
            args = ["a"]
        index = len(args) - 1
        # Keep option structure fixed, mutating only a data argument.
        value = args[index].encode("utf-8")
        mutated = mutate_bytes(value, rng).replace(b"\x00", b"_")
        args[index] = mutated.decode("utf-8", errors="replace")
        return replace(seed, args=tuple(args))
    if seed.files:
        files = list(seed.files)
        index = rng.randrange(len(files))
        name, content = files[index]
        files[index] = (name, mutate_bytes(content, rng))
        return replace(seed, files=tuple(files))
    return replace(seed, stdin=mutate_bytes(seed.stdin, rng))


def encode_case(case: Case) -> dict:
    return {"util": case.util, "locale": case.locale, "args": list(case.args),
            "stdin_b64": base64.b64encode(case.stdin).decode("ascii"),
            "files": [[name, base64.b64encode(data).decode("ascii")]
                      for name, data in case.files], "dirs": list(case.dirs)}


def decode_case(record: dict) -> Case:
    return Case("gnu", record["util"], "replay", tuple(record["args"]),
                base64.b64decode(record["stdin_b64"]),
                tuple((name, base64.b64decode(data)) for name, data in record["files"]),
                tuple(record["dirs"]), locale=record.get("locale", "C"))


def compare(binary: Path, case: Case) -> tuple[str, tuple | None, tuple | None, tuple | None]:
    try:
        gnu = execute(reference_command("gnu", case.util), case)
        uutils = execute(reference_command("uutils", case.util), case)
    except ExecutionTimeout:
        return "reference timeout", None, None, None
    if gnu != uutils:
        return "reference disagreement", gnu, uutils, None
    try:
        actual = execute([str(binary), case.util], case)
    except ExecutionTimeout:
        return "lutils timeout", gnu, uutils, None
    return ("pass" if actual == gnu else "lutils mismatch"), gnu, uutils, actual


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, default=ROOT/".lake/build/bin/lutils")
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--iterations", type=int, default=100)
    parser.add_argument("--util", action="append", choices=sorted(UTILS))
    parser.add_argument("--locale", action="append",
                        help="limit mutation seeds to a locale; repeat to select several")
    parser.add_argument("--save-dir", type=Path, help="write replayable mismatch cases here")
    parser.add_argument("--replay", type=Path, help="run one saved case")
    args = parser.parse_args()
    if args.iterations < 1:
        parser.error("iterations must be positive")
    if not SOURCES.is_dir():
        parser.error("run inside `nix develop`")
    if not args.no_build:
        subprocess.run(["lake", "build", "lutils"], cwd=ROOT, check=True)
    binary = args.bin.resolve()
    if not binary.is_file():
        parser.error(f"binary does not exist: {binary}")
    if args.replay:
        record = json.loads(args.replay.read_text())
        args.seed = record.get("seed", args.seed)
        selected = [(record.get("iteration", 0), decode_case(record["case"]))]
    else:
        chosen = set(args.util or UTILS)
        seeds = [c for c in cases(SOURCES, locales=tuple(args.locale or ("C", "C.UTF-8")))
                 if c.family == "gnu" and c.util in chosen
                 and c.expected is None and not c.dirs]
        if not seeds:
            parser.error("no eligible seed cases")
        rng = random.Random(args.seed)
        selected = [(index, mutate(rng.choice(seeds), rng)) for index in range(args.iterations)]
    totals = {"pass": 0, "lutils mismatch": 0,
              "lutils timeout": 0, "reference disagreement": 0,
              "reference timeout": 0}
    details = []
    for index, case in selected:
        result, gnu, uutils, actual = compare(binary, case)
        totals[result] += 1
        if result != "pass":
            if result.endswith("timeout"):
                comparison = "process exceeded the execution timeout"
            else:
                comparison = describe_difference(gnu, uutils if actual is None else actual)
            details.append(f"{index}: {case.util} [{case.locale}] {case.args!r}: "
                           f"{result}; {comparison}")
            if args.save_dir and result == "lutils mismatch":
                args.save_dir.mkdir(parents=True, exist_ok=True)
                target = args.save_dir / f"seed-{args.seed}-case-{index}-{case.util}.json"
                target.write_text(json.dumps({"seed": args.seed, "iteration": index,
                                              "case": encode_case(case)}, indent=2) + "\n")
    print(f"seed {args.seed}: {totals['pass']} passed; "
          f"{totals['lutils mismatch']} lutils mismatches; "
          f"{totals['lutils timeout']} lutils timeouts; "
          f"{totals['reference disagreement']} GNU/uutils disagreements; "
          f"{totals['reference timeout']} reference timeouts")
    for detail in details[:20]:
        print(detail)
    if len(details) > 20:
        print(f"... {len(details)-20} more differences omitted")
    return 1 if totals["lutils mismatch"] or totals["lutils timeout"] else 0


if __name__ == "__main__":
    sys.exit(main())
