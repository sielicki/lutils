"""Check that the generated status table remains valid GitHub Markdown."""

from pathlib import Path
import re
import unittest


class StatusMarkdownTests(unittest.TestCase):
    def test_table_rows_match_header_width(self):
        status = Path(__file__).with_name("STATUS.md").read_text().splitlines()
        start = next(i for i, line in enumerate(status)
                     if line.startswith("| Project") and "| Utility" in line)
        table = []
        for line in status[start:]:
            if not line.startswith("|"):
                break
            table.append(line)
        self.assertGreater(len(table), 2)
        columns = table[0].count("|") - 1
        self.assertEqual(columns, 13)
        separators = [cell.strip() for cell in table[1].strip("|").split("|")]
        self.assertTrue(all(re.fullmatch(r":?-{3,}:?", cell) for cell in separators))
        for line in table[1:]:
            self.assertEqual(line.count("|") - 1, columns, line)


if __name__ == "__main__":
    unittest.main()
