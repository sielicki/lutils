"""Checks for the differential harness itself."""

from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from corpus import Case, permute_locales, run_cases
from differential import compare, decode_case, encode_case, mutate
from reference import ExecutionTimeout, execute, snapshot
from report import check_case
import random


class HarnessTests(unittest.TestCase):
    def test_case_round_trip_preserves_binary_inputs(self):
        case = Case("gnu", "cat", "binary", stdin=b"a\x00\xff\n",
                    files=(("input", b"\x00\xff"),), dirs=("empty",),
                    locale="C.UTF-8")
        restored = decode_case(encode_case(case))
        self.assertEqual((restored.util, restored.args, restored.stdin,
                          restored.files, restored.dirs, restored.locale),
                         (case.util, case.args, case.stdin, case.files, case.dirs,
                          case.locale))

    def test_mutation_is_reproducible_and_bounded(self):
        case = Case("gnu", "cat", "seed", stdin=b"a" * 256)
        first = mutate(case, random.Random(42))
        second = mutate(case, random.Random(42))
        self.assertEqual(first, second)
        self.assertLessEqual(len(first.stdin), 256)
        self.assertNotEqual(first.stdin, case.stdin)

    def test_snapshot_records_type_mode_and_symlink_target(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/"target").write_bytes(b"hello")
            (root/"alias").symlink_to("target")
            (root/"folder").mkdir()
            os.chmod(root/"target", 0o600)
            entries = {item[0]: item[1:] for item in snapshot(root)}
            self.assertEqual(entries["target"][:4], ("file", 0o600, os.getuid(), os.getgid()))
            self.assertEqual(entries["target"][4], b"hello")
            self.assertEqual(entries["alias"][0], "symlink")
            self.assertEqual(entries["alias"][4], "target")
            self.assertEqual(entries["folder"][0], "dir")

    def test_snapshot_distinguishes_hard_links_from_copies(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/"source").write_bytes(b"same")
            (root/"hard-link").hardlink_to(root/"source")
            (root/"copy").write_bytes(b"same")
            entries = {item[0]: item for item in snapshot(root)}
            self.assertEqual(entries["source"][-1], ("hard-link", "source"))
            self.assertEqual(entries["hard-link"][-1], ("hard-link", "source"))
            self.assertEqual(entries["copy"][-1], ())

    def test_execute_uses_fresh_fixture_each_time(self):
        case = Case("gnu", "cat", "fixture", args=("input",),
                    files=(("input", b"content\n"),))
        command = [sys.executable, "-c",
                   "from pathlib import Path; import sys; sys.stdout.buffer.write(Path('input').read_bytes())"]
        self.assertEqual(execute(command, case), execute(command, case))

    def test_locale_permutation_and_execution(self):
        base = Case("gnu", "cat", "locale", locales=("C.UTF-8",))
        with patch("corpus.validate_locale"):
            selected = permute_locales([base], ("C", "C.UTF-8"))
        self.assertEqual([case.locale for case in selected], ["C.UTF-8"])
        command = [sys.executable, "-c",
                   "import os, sys; sys.stdout.write(os.environ['LC_ALL'] + '|' + os.environ['LANG'])"]
        for output_limit in (None, 64):
            case = Case("gnu", "cat", "locale", locale="C.UTF-8",
                        output_limit=output_limit)
            with patch("reference.validate_locale"):
                status, stdout, _, _ = execute(command, case)
            self.assertEqual((status, stdout), (0, b"C.UTF-8|C.UTF-8"))

        output = io.StringIO()
        failing = Case("behavior", "cat", "locale-label", expected=b"expected",
                       locale="C.UTF-8")
        def wrong_output(_binary, _case, *, elapsed_out):
            elapsed_out.append(0.0)
            return (0, b"actual", b"", ())
        with patch("corpus.execute", side_effect=wrong_output):
            with redirect_stdout(output):
                failures, total = run_cases(Path("unused"), [failing], Path("unused"))
        self.assertEqual((failures, total), (1, 1))
        self.assertIn("behavior/cat/locale-label [C.UTF-8]", output.getvalue())

    def test_execute_rejects_timeout(self):
        case = Case("gnu", "cat", "timeout")
        command = [sys.executable, "-c", "import time; time.sleep(1)"]
        with self.assertRaisesRegex(ExecutionTimeout, "exceeded"):
            execute(command, case, timeout=0.05)

    def test_bounded_output_handles_large_stderr(self):
        case = Case("gnu", "yes", "bounded", output_limit=9)
        command = [sys.executable, "-c",
                   "import sys\n"
                   "sys.stderr.buffer.write(b'e' * 131072)\n"
                   "sys.stderr.flush()\n"
                   "while True:\n"
                   "    sys.stdout.buffer.write(b'yes\\n' * 2048)\n"
                   "    sys.stdout.flush()\n"]
        status, stdout, stderr, _ = execute(command, case, timeout=2)
        self.assertEqual((status, stdout, stderr), ("prefix", b"yes\nyes\ny", b"e" * 131072))

    def test_bounded_finite_output_keeps_exit_status(self):
        case = Case("gnu", "yes", "finite", output_limit=4)
        command = [sys.executable, "-c", "import sys; sys.stdout.write('done')"]
        status, stdout, _, _ = execute(command, case, timeout=2)
        self.assertEqual((status, stdout), (0, b"done"))

    def test_uutils_diagnostic_prefix_only_normalizes_stderr(self):
        with tempfile.TemporaryDirectory() as temp:
            binary = Path(temp)/"uutils-cat"
            binary.write_text(f"#!{sys.executable}\n"
                              "import sys\n"
                              "sys.stdout.write('uutils-cat: data\\n')\n"
                              "sys.stderr.write('uutils-cat: bad\\ninside uutils-cat: data\\n')\n")
            binary.chmod(0o755)
            case = Case("uutils", "cat", "diagnostic")
            _, stdout, stderr, _ = execute([str(binary)], case)
            self.assertEqual(stdout, b"uutils-cat: data\n")
            self.assertEqual(stderr, b"cat: bad\ninside uutils-cat: data\n")

    def test_compare_separates_reference_disagreement(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            commands = []
            for name, value in (("gnu", "one"), ("uutils", "two"), ("lean", "three")):
                script = root/name
                script.write_text(f"#!{sys.executable}\nimport sys\nsys.stdout.write({value!r})\n")
                script.chmod(0o755)
                commands.append(script)
            case = Case("gnu", "cat", "comparison")
            with patch("differential.reference_command",
                       side_effect=lambda family, util: [str(root/family)]):
                category, _, _, actual = compare(commands[2], case)
            self.assertEqual(category, "reference disagreement")
            self.assertIsNone(actual)
            (root/"uutils").write_text((root/"gnu").read_text())
            with patch("differential.reference_command",
                       side_effect=lambda family, util: [str(root/family)]):
                category, _, _, actual = compare(commands[2], case)
            self.assertEqual(category, "lutils mismatch")
            self.assertIsNotNone(actual)

    def test_compare_reports_reference_and_lutils_timeouts(self):
        case = Case("gnu", "cat", "timeouts")
        with patch("differential.reference_command", return_value=["reference"]):
            with patch("differential.execute", side_effect=ExecutionTimeout("reference timed out")):
                category, gnu, uutils, actual = compare(Path("lutils"), case)
            self.assertEqual(category, "reference timeout")
            self.assertEqual((gnu, uutils, actual), (None, None, None))

            result = (0, b"ok\n", b"", ())
            with patch("differential.execute",
                       side_effect=[result, result, ExecutionTimeout("lutils timed out")]):
                category, gnu, uutils, actual = compare(Path("lutils"), case)
            self.assertEqual(category, "lutils timeout")
            self.assertEqual((gnu, uutils, actual), (result, result, None))

    def test_run_cases_enforces_minimum_runtime(self):
        case = Case("behavior", "sleep", "minimum", expected=b"", min_runtime=0.4)
        def immediate(_binary, _case, *, elapsed_out):
            elapsed_out.append(0.001)
            return (0, b"", b"", ())
        with patch("corpus.execute", side_effect=immediate):
            with redirect_stdout(io.StringIO()):
                failures, total = run_cases(Path("unused"), [case], Path("unused"))
        self.assertEqual((failures, total), (1, 1))

    def test_missing_reference_aborts_instead_of_counting_lutils_failure(self):
        case = Case("gnu", "cat", "missing-reference")
        with patch("corpus.reference_command", side_effect=RuntimeError("unavailable")):
            with self.assertRaisesRegex(RuntimeError, "invalid reference"):
                run_cases(Path("unused"), [case], Path("unused"))
        with patch("report.reference_command", side_effect=RuntimeError("unavailable")):
            with self.assertRaisesRegex(RuntimeError, "unavailable"):
                check_case(case, Path("unused"))


if __name__ == "__main__":
    unittest.main()
