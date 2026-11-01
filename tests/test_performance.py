"""Regression checks for semantic validation in the performance harness."""

import os
import sys
import unittest

from performance import Scenario, benchmark


class PerformanceHarnessTests(unittest.TestCase):
    def test_rejects_same_size_wrong_stdout(self):
        good = [sys.executable, "-c", "print('right')"]
        bad = [sys.executable, "-c", "print('wrong')"]
        scenario = Scenario("stdout check", "fake", ())
        result = benchmark(scenario, {"lutils": bad, "GNU": good, "uutils": good},
                           1, 1, dict(os.environ))
        self.assertIn("stdout differs", result["implementations"]["lutils"]["error"])
        self.assertIsNone(result["implementations"]["lutils"]["median_ms"])
        self.assertIsNotNone(result["implementations"]["GNU"]["median_ms"])

    def test_rejects_wrong_copied_file(self):
        good = [sys.executable, "-c", "from pathlib import Path; "
                "Path('output').write_bytes(Path('input').read_bytes())"]
        bad = [sys.executable, "-c", "from pathlib import Path; "
               "Path('output').write_bytes(b'wrong')"]
        scenario = Scenario("copy check", "fake", (), input_file=True,
                            output_file=True, rate_basis="copy")
        result = benchmark(scenario, {"lutils": bad, "GNU": good, "uutils": good},
                           1, 1, dict(os.environ))
        self.assertIn("copied file differs", result["implementations"]["lutils"]["error"])
        self.assertIsNone(result["implementations"]["lutils"]["median_ms"])
        self.assertEqual(result["work_bytes"], 1024 * 1024)
        self.assertGreater(result["implementations"]["GNU"]["effective_mib_s"], 0)


if __name__ == "__main__":
    unittest.main()
