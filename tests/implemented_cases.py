"""Deeper reference-backed cases for implemented applets.

Each invocation runs in a fresh temporary directory. In particular, the
filesystem cases exercise the resulting tree, not just the process streams.
The GNU and uutils variants intentionally remain separate observations: a
disagreement between those programs is useful evidence, not a reason to drop
the case.
"""

import base64

from corpus import Case


def implemented_cases() -> list[Case]:
    out: list[Case] = []

    def both(util: str, name: str, args=(), *, stdin=b"", files=(), dirs=(),
             links=(), output_limit=None) -> None:
        for family in ("gnu", "uutils"):
            out.append(Case(family, util, name, tuple(args), stdin,
                            tuple(files), tuple(dirs), links=tuple(links),
                            output_limit=output_limit))

    # RFC 4648 encoders and the additional basenc alphabets.
    for util, encoded in (("base64", b"YWJj"), ("base32", b"MFRGG===")):
        both(util, "binary-input", stdin=bytes(range(256)))
        both(util, "wrap-boundary", stdin=b"a" * 100)
        both(util, "no-wrap", ["-w0"], stdin=b"a" * 100)
        both(util, "custom-wrap", ["-w", "5"], stdin=b"a" * 20)
        both(util, "stream-chunk-boundary", ["-w", "5", "data"],
             files=[("data", b"abcde" * (4 * 1024 * 1024 // 5) + b"tail")])
        both(util, "decode", ["-d"], stdin=encoded + b"\n")
        both(util, "decode-file", ["-d", "data"], files=[("data", encoded)])
        both(util, "decode-garbage", ["-di"], stdin=encoded[:2] + b"!" + encoded[2:])
        # GNU emits the decoded prefix; uutils discards it and uses different error text.
        out.append(Case("gnu", util, "invalid-input", ("-d",), encoded + b"!"))
        out.append(Case("gnu", util, "invalid-padding", ("-d",),
                        b"YQ=" if util == "base64" else b"ME="))
        large_plain = (b"abc" * 1_100_000 if util == "base64"
                       else b"abcde" * 550_000)
        large_encoded = (base64.b64encode(large_plain) if util == "base64"
                         else base64.b32encode(large_plain))
        both(util, "decode-stream-chunk-boundary", ["-d", "data"],
             files=[("data", large_encoded)])
    both("base64", "decode-newline-at-chunk-boundary", ["-d", "data"],
         files=[("data", b"A" * (4 * 1024 * 1024 - 1) + b"\n" + b"A" * 8)])
    basenc_vectors = {
        "base64": (b"abc", b"YWJj"),
        "base64url": (b"abc", b"YWJj"),
        "base32": (b"abc", b"MFRGG==="),
        "base32hex": (b"abc", b"C5H66==="),
        "base16": (b"abc", b"616263"),
        "base2msbf": (b"abc", b"011000010110001001100011"),
        "base2lsbf": (b"abc", b"100001100100011011000110"),
        "base58": (b"abc", b"ZiCa"),
        "z85": (b"abcd", b"vpA.S"),
    }
    for format_name, (plain, encoded) in basenc_vectors.items():
        both("basenc", f"{format_name}-encode", [f"--{format_name}"], stdin=plain)
        both("basenc", f"{format_name}-decode", [f"--{format_name}", "-d"],
             stdin=encoded + b"\n")
    both("basenc", "stream-chunk-boundary", ["--base64url", "-w", "5", "data"],
         files=[("data", b"abcde" * (4 * 1024 * 1024 // 5) + b"tail")])
    both("basenc", "z85-decode-stream-boundary", ["--z85", "-d", "data"],
         files=[("data", b"00000" * (4 * 1024 * 1024 // 5 + 1))])

    # Digest block boundaries, binary input, output modes, and manifest checks.
    # The "abc" digests are the published test vectors for each algorithm.
    abc_digests = {
        "b2sum": "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923",
        "md5sum": "900150983cd24fb0d6963f7d28e17f72",
        "sha1sum": "a9993e364706816aba3e25717850c26c9cd0d89d",
        "sha224sum": "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7",
        "sha256sum": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        "sha384sum": "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed"
                     "8086072ba1e7cc2358baeca134c825a7",
        "sha512sum": "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
                     "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
    }
    for util, abc_digest in abc_digests.items():
        both(util, "binary-stdin", stdin=bytes(range(256)))
        both(util, "block-boundary-55", stdin=b"a" * 55)
        both(util, "block-boundary-56", stdin=b"a" * 56)
        both(util, "several-blocks", stdin=b"a" * 1000)
        both(util, "binary-file", ["data"], files=[("data", b"a\0\xffz")])
        both(util, "several-files", ["a", "b"],
             files=[("a", b"abc"), ("b", b"xyz")])
        both(util, "tagged", ["--tag", "data"], files=[("data", b"abc")])
        both(util, "binary-mode", ["-b", "data"], files=[("data", b"abc")])
        both(util, "zero-terminated", ["-z", "data"], files=[("data", b"abc")])
        both(util, "escaped-filename", ["a\\b"], files=[("a\\b", b"abc")])
        both(util, "missing-file", ["missing"])
        both(util, "check-valid", ["-c", "manifest"],
             files=[("data", b"abc"),
                    ("manifest", (abc_digest
                                  + "  data\n").encode())])
        both(util, "check-crlf", ["-c", "manifest"],
             files=[("data", b"abc"),
                    ("manifest", (abc_digest
                                  + "  data\r\n").encode())])
        both(util, "check-mismatch", ["-c", "manifest"],
             files=[("data", b"xyz"),
                    ("manifest", (abc_digest
                                  + "  data\n").encode())])
        if util == "sha256sum":
            both(util, "check-unmarked-name", ["-c", "manifest"],
                 files=[("data", b"abc"),
                        ("manifest", b"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad 9data\n")])

    for bits in (0, 8, 128, 256, 504, 512):
        both("b2sum", f"length-{bits}", [f"--length={bits}"], stdin=b"abc")
        both("b2sum", f"tagged-length-{bits}", ["--tag", f"-l{bits}"], stdin=b"abc")
    for size in (0, 1, 127, 128, 129, 255, 256, 4 * 1024 * 1024 + 1):
        both("b2sum", f"boundary-{size}", stdin=b"a" * size)
    both("b2sum", "check-mixed-lengths", ["--check", "manifest"],
         files=[("data", b"abc"),
                ("manifest", b"bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319  data\n"
                             b"BLAKE2b (data) = ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923\n")])
    # GNU localizes diagnostic quotes; uutils uses ASCII quotes in both locales.
    for length in ("7", "513", "oops"):
        out.append(Case("gnu", "b2sum", f"invalid-length-{length}",
                        ("-l", length), b"abc"))

    # Whole-line and numeric sorting, stability, and checking.
    both("sort", "basic-order", stdin=b"delta\nalpha\ngamma\nbeta\n")
    both("sort", "numeric", ["-n"], stdin=b"10\n9\n-3\n 2.5\n2.25\n")
    both("sort", "numeric-last-resort", ["-n"], stdin=b"b1\na2\nb0\n")
    both("sort", "numeric-stable", ["-ns"], stdin=b"b1\na2\nb0\n")
    both("sort", "numeric-unique-first", ["-nu"], stdin=b"a2\nb1\na1\n")
    both("sort", "fold-case-unique", ["-fu"], stdin=b"B\nb\na\n")
    both("sort", "leading-blanks", ["-b"], stdin=b"  b\na\n c\n")
    both("sort", "check-ordered", ["-c"], stdin=b"a\nb\n")
    both("sort", "check-disorder", ["-c"], stdin=b"b\na\n")
    both("sort", "check-quiet", ["-C"], stdin=b"b\na\n")
    both("sort", "output-file", ["-o", "output", "input"],
         files=[("input", b"b\na\n")])
    both("sort", "several-files", ["one", "two"],
         files=[("one", b"b\nc\n"), ("two", b"a\n")])
    both("sort", "missing-file", ["missing"])
    both("sort", "zero-terminated", ["-z"], stdin=b"b\0a\0")
    both("sort", "binary-input", stdin=b"b\xff\na\xfe\n")

    # Adjacent-duplicate filtering, including the comparison-key options.
    lines = b"a\na\nB\nb\nc"
    both("uniq", "adjacent-only", stdin=b"a\nb\na\n")
    both("uniq", "count", ["-c"], stdin=lines)
    both("uniq", "repeated", ["-d"], stdin=lines)
    both("uniq", "unique", ["-u"], stdin=lines)
    both("uniq", "all-repeated", ["-D"], stdin=lines)
    both("uniq", "ignore-case-count", ["-ic"], stdin=lines)
    both("uniq", "skip-fields", ["-f", "1"], stdin=b" x a\n y a\n z b\n")
    both("uniq", "skip-and-check", ["-s2", "-w1"], stdin=b"zzax\nqqay\n")
    both("uniq", "zero-terminated", ["-z"], stdin=b"a\0a\0b\0")
    both("uniq", "group-separate", ["--group"], stdin=b"a\na\nb\n")
    both("uniq", "output-operand", ["input", "output"],
         files=[("input", b"x\nx\ny\n")])
    both("uniq", "missing-file", ["missing"])
    both("uniq", "binary-input", stdin=b"a\xffb\na\xfeb\na\xffb\n")

    # Byte, character, and field selection. GNU-only cases cover list errors,
    # whose wording uutils does not share.
    both("cut", "char-ranges", ["-c", "4,1-2"], stdin=b"abcdef\nxy\n")
    both("cut", "fields-reordered", ["-d:", "-f", "3,1"], stdin=b"a:b:c\n")
    both("cut", "only-delimited", ["-s", "-f", "2"], stdin=b"nod\nx\ty\n")
    both("cut", "output-delimiter", ["-f", "1,3", "--output-delimiter=|"],
         stdin=b"a\tb\tc\n")
    both("cut", "complement-chars", ["-c", "2-3", "--complement"],
         stdin=b"abcdef\n")
    both("cut", "zero-terminated", ["-z", "-c", "1"], stdin=b"ab\0cd\0")
    both("cut", "missing-file", ["-c", "1", "missing"])
    out.append(Case("gnu", "cut", "no-list", (), b"a\n"))
    out.append(Case("gnu", "cut", "decreasing-range", ("-c", "3-2"), b"a\n"))
    out.append(Case("gnu", "cut", "two-lists", ("-c", "1", "-f", "1"), b"a\n"))

    # Translation tables pair expanded set elements; deletion and squeezing
    # act on set membership.
    both("tr", "case-map", ["a-z", "A-Z"], stdin=b"hello\n")
    both("tr", "padded-set2", ["abc", "xy"], stdin=b"abc\n")
    both("tr", "truncate", ["-t", "abc", "xy"], stdin=b"abc\n")
    both("tr", "classes", ["[:upper:]", "[:lower:]"], stdin=b"aB1 \n")
    both("tr", "complement", ["-c", "a-z", "*"], stdin=b"abc123\n")
    both("tr", "delete-complement", ["-cd", "a-z"], stdin=b"abc123\n")
    both("tr", "squeeze-translated", ["-s", "a", "x"], stdin=b"aabb\n")
    both("tr", "delete-and-squeeze", ["-ds", "a", "b"], stdin=b"aaabb\n")
    both("tr", "repeat-fill", ["a-c", "[x*]"], stdin=b"abc\n")
    both("tr", "repeat-count", ["a", "[x*2]y"], stdin=b"aab\n")
    out.append(Case("gnu", "tr", "missing-operand", (), b"a\n"))
    out.append(Case("gnu", "tr", "reversed-range", ("z-a", "x"), b"a\n"))

    # The legacy checksums, in `cksum` and `sum` form, share renderings.
    for util, prefix in (("cksum", ()), ("sum", ())):
        both(util, "default-stdin", prefix, stdin=b"abc")
        both(util, "empty-stdin", prefix)
    for algorithm in ("bsd", "sysv", "crc", "crc32b"):
        both("cksum", f"algorithm-{algorithm}", ["-a", algorithm, "data"],
             files=[("data", b"a" * 1234)])
    for algorithm in ("md5", "sha512"):
        both("cksum", f"algorithm-{algorithm}", ["-a", algorithm, "data"],
             files=[("data", b"abc")])
        both("cksum", f"algorithm-{algorithm}-untagged",
             ["-a", algorithm, "--untagged", "data"], files=[("data", b"abc")])
    both("cksum", "check-autodetect", ["-c", "manifest"],
         files=[("data", b"abc"),
                ("manifest", b"MD5 (data) = 900150983cd24fb0d6963f7d28e17f72\n")])
    both("sum", "sysv-flag", ["-s", "data"], files=[("data", b"a" * 1234)])
    both("sum", "several-files", ["a", "b"], files=[("a", b"abc"), ("b", b"")])

    # Copying an existing target, several sources, trees, and links has
    # different behavior from copying one regular file to a new name.
    both("cp", "overwrite-file", ["source", "target"],
         files=[("source", b"new\0value\n"), ("target", b"old\n")])
    both("cp", "into-directory", ["source", "dest"],
         files=[("source", b"payload")], dirs=["dest"])
    both("cp", "several-into-directory", ["one", "two", "dest"],
         files=[("one", b"1"), ("two", b"2")], dirs=["dest"])
    both("cp", "recursive-tree", ["-R", "tree", "copy"],
         files=[("tree/inner/data", b"nested\n")], dirs=["tree/empty"])
    both("cp", "recursive-into-directory", ["-R", "tree", "dest"],
         files=[("tree/data", b"contents")], dirs=["dest"])
    both("cp", "copy-symlink-itself", ["-P", "alias", "copy"],
         files=[("source", b"contents")], links=[("alias", "source")])
    both("cp", "copy-symlink-target", ["-L", "alias", "copy"],
         files=[("source", b"contents")], links=[("alias", "source")])
    both("cp", "no-clobber", ["-n", "source", "target"],
         files=[("source", b"new"), ("target", b"old")])
    both("cp", "leading-dash-operand", ["--", "-source", "copy"],
         files=[("-source", b"dash")])
    both("cp", "missing-source", ["absent", "target"])

    both("mv", "overwrite-file", ["source", "target"],
         files=[("source", b"new"), ("target", b"old")])
    both("mv", "into-directory", ["source", "dest"],
         files=[("source", b"data")], dirs=["dest"])
    both("mv", "several-into-directory", ["one", "two", "dest"],
         files=[("one", b"1"), ("two", b"2")], dirs=["dest"])
    both("mv", "directory-tree", ["tree", "renamed"],
         files=[("tree/inner/data", b"nested")], dirs=["tree/empty"])
    both("mv", "symlink-itself", ["alias", "moved"],
         files=[("source", b"data")], links=[("alias", "source")])
    both("mv", "no-clobber", ["-n", "source", "target"],
         files=[("source", b"new"), ("target", b"old")])
    both("mv", "leading-dash-operand", ["--", "-source", "moved"],
         files=[("-source", b"dash")])
    both("mv", "missing-source", ["absent", "target"])

    both("rm", "several-files", ["one", "two"],
         files=[("one", b"1"), ("two", b"2")])
    both("rm", "recursive-tree", ["-r", "tree"],
         files=[("tree/inner/data", b"nested")], dirs=["tree/empty"])
    both("rm", "empty-directory", ["-d", "empty"], dirs=["empty"])
    both("rm", "directory-without-recursion", ["tree"],
         files=[("tree/data", b"keep")])
    both("rm", "force-missing", ["-f", "absent"])
    both("rm", "missing-file", ["absent"])
    both("rm", "leading-dash-operand", ["--", "-file"],
         files=[("-file", b"data")])
    both("rm", "remove-symlink-only", ["alias"],
         files=[("source", b"keep")], links=[("alias", "source")])
    both("rm", "recursive-symlink-only", ["-r", "alias"],
         files=[("tree/data", b"keep")], links=[("alias", "tree")])

    listing = [("alpha", b"aa"), ("beta", b"b"),
               (".secret", b"hidden"), ("sub/child", b"inside")]
    both("ls", "hidden-excluded", ["-1", "."], files=listing)
    both("ls", "hidden-included", ["-1a", "."], files=listing)
    both("ls", "almost-all", ["-1A", "."], files=listing)
    both("ls", "reverse-order", ["-1r", "."], files=listing)
    both("ls", "sort-by-size", ["-1S", "."], files=listing)
    both("ls", "directory-indicator", ["-1p", "."], files=listing)
    both("ls", "recursive-tree", ["-1R", "sub"], files=listing)
    both("ls", "directory-as-operand", ["-1d", "sub"], files=listing)
    both("ls", "symlink-as-operand", ["-1d", "alias"],
         files=[("target", b"content")], links=[("alias", "target")])
    both("ls", "file-and-directory-operands", ["-1", "alpha", "sub"],
         files=listing)

    both("mkdir", "nested-parents", ["-p", "first/second/third"])
    both("mkdir", "several-directories", ["first", "second"])
    both("mkdir", "explicit-mode", ["-m", "700", "private"])
    both("mkdir", "existing-with-parents", ["-p", "existing"],
         dirs=["existing"])
    both("mkdir", "existing-without-parents", ["existing"],
         dirs=["existing"])
    both("mkdir", "parent-is-file", ["-p", "file/child"],
         files=[("file", b"ordinary")])
    both("mkdir", "leading-dash-operand", ["--", "-directory"])

    lines = b"one\ntwo\nthree\nfour\nfive\n"
    both("tail", "empty-input", stdin=b"")
    both("tail", "fewer-than-ten-lines", stdin=lines)
    both("tail", "zero-lines", ["-n", "0"], stdin=lines)
    both("tail", "last-two-lines", ["-n", "2"], stdin=lines)
    both("tail", "last-four-bytes", ["-c", "4"], stdin=lines)
    both("tail", "from-second-line", ["-n", "+2"], stdin=lines)
    both("tail", "from-second-byte", ["-c", "+2"], stdin=lines)
    both("tail", "unterminated-last-line", ["-n", "1"],
         stdin=b"first\nlast")
    both("tail", "binary-data", ["-c", "6"], stdin=b"a\0b\nc\0d")
    both("tail", "multiple-file-headers", ["-n", "1", "first", "second"],
         files=[("first", b"a\nb\n"), ("second", b"c\nd\n")])
    both("tail", "multiple-file-quiet", ["-q", "-n", "1", "first", "second"],
         files=[("first", b"a\nb\n"), ("second", b"c\nd\n")])
    both("tail", "one-file-verbose", ["-v", "-n", "1", "first"],
         files=[("first", b"a\nb\n")])

    both("wc", "empty-stdin", stdin=b"")
    both("wc", "mixed-whitespace", stdin=b"one\ttwo  three\n\nfour\r\nfive")
    both("wc", "unterminated-line", stdin=b"a b")
    both("wc", "line-count", ["-l"], stdin=b"a\nb\nlast")
    both("wc", "byte-count", ["-c"], stdin=b"a\0b\nc")
    both("wc", "word-count", ["-w"], stdin=b"  one\ttwo\nthree  ")
    both("wc", "word-across-read-boundary", ["-w", "input"],
         files=[("input", b"a" * (4 * 1024 * 1024 + 3) + b" b\n")])
    both("wc", "max-line-length", ["-L"], stdin=b"a\n12345\nxx\n")
    both("wc", "all-counts-file", ["-lwc", "input"],
         files=[("input", b"one two\nthree\n")])
    both("wc", "multiple-files-total", ["-lwc", "first", "second"],
         files=[("first", b"a\nb\n"), ("second", b"c d\n")])
    both("wc", "explicit-stdin-operand", ["-"], stdin=b"a b\n")
    # GNU wc changes its character, word, and display-width counts between C
    # and UTF-8 locales. Running the same bytes in both exposes that contract.
    both("wc", "unicode-character-count", ["-m"], stdin="é中🙂\n".encode())
    both("wc", "unicode-words", ["-w"], stdin="café 中🙂\n".encode())
    both("wc", "unicode-word-separator", ["-w"], stdin="un\u2003deux\n".encode())
    both("wc", "unicode-display-width", ["-L"], stdin="中🙂\n".encode())

    # `comm` merges one record from each sorted source at a time. Exercise
    # column selection, record delimiters, and large records crossing reads.
    comm_files = [("left", b"a\nb\nb\nd\n"), ("right", b"b\nb\nc\nd\n")]
    both("comm", "merged-duplicates", ["left", "right"], files=comm_files)
    both("comm", "first-column", ["-23", "left", "right"], files=comm_files)
    both("comm", "second-column", ["-13", "left", "right"], files=comm_files)
    both("comm", "common-column", ["-12", "left", "right"], files=comm_files)
    both("comm", "all-suppressed", ["-123", "left", "right"], files=comm_files)
    both("comm", "totals", ["--total", "-123", "left", "right"], files=comm_files)
    both("comm", "custom-column-delimiter",
         ["--output-delimiter=::", "left", "right"], files=comm_files)
    both("comm", "empty-column-delimiter",
         ["--output-delimiter=", "left", "right"], files=comm_files)
    both("comm", "unterminated-record", ["left", "right"],
         files=[("left", b"a\nb"), ("right", b"b\nc")])
    both("comm", "zero-terminated", ["-z", "left", "right"],
         files=[("left", b"a\0b\0"), ("right", b"b\0c\0")])
    both("comm", "stdin-and-file", ["-", "right"], stdin=b"a\nb\n",
         files=[("right", b"b\nc\n")])
    # GNU consumes two stdin operands from the same stream in alternating reads.
    # The current uutils reference hangs on this case.
    out.append(Case("gnu", "comm", "two-stdin-operands", ("-", "-"), b"a\nb\nc\n"))
    both("comm", "long-record", ["left", "right"],
         files=[("left", b"a" * (64 * 1024 + 5) + b"\n"),
                ("right", b"a" * (64 * 1024 + 5) + b"\n")])
    both("comm", "check-order", ["--check-order", "left", "right"],
         files=[("left", b"b\na\n"), ("right", b"a\nb\n")])
    both("comm", "nocheck-order", ["--nocheck-order", "left", "right"],
         files=[("left", b"b\na\n"), ("right", b"a\nb\n")])

    # Streaming column assembly, delimiter cycling, and shared stdin operands.
    paste_files = (("left", b"a\nb\nlast"), ("right", b"1\n2\n"))
    both("paste", "parallel", ["left", "right"], files=paste_files)
    both("paste", "serial", ["-s", "left", "right"], files=paste_files)
    both("paste", "delimiter-cycle", ["-d", ",:", "left", "right", "left"],
         files=paste_files)
    both("paste", "empty-delimiter", ["-d", "\\0", "left", "right"],
         files=paste_files)
    both("paste", "empty-delimiter-list", ["-d", "", "left", "right"],
         files=paste_files)
    both("paste", "clustered-serial-delimiters", ["-sd", ":", "left", "right"],
         files=paste_files)
    both("paste", "zero-terminated", ["-z", "left", "right"],
         files=(("left", b"a\0b\0"), ("right", b"x\0")))
    both("paste", "empty-file-serial", ["-s", "left", "right"],
         files=(("left", b""), ("right", b"x\n")))
    both("paste", "repeated-stdin", ["-", "-"], stdin=b"a\nb\nc\n")
    both("paste", "long-record", ["left", "right"],
         files=(("left", b"a" * (128 * 1024) + b"\n"), ("right", b"x\n")))
    out.append(Case("gnu", "paste", "missing-serial", ("-s", "missing", "left"),
                    files=paste_files))
    out.append(Case("gnu", "paste", "missing-parallel", ("missing", "left"),
                    files=paste_files))
    out.append(Case("gnu", "paste", "trailing-backslash-delimiter",
                    ("-d", "\\", "left", "right"), files=paste_files))
    out.append(Case("gnu", "paste", "directory-parallel",
                    ("dir", "left"), files=paste_files, dirs=("dir",)))
    out.append(Case("gnu", "paste", "directory-serial",
                    ("-s", "dir", "left"), files=paste_files, dirs=("dir",)))

    # Raw byte comparison, bounded reads, offsets, and diagnostic modes.
    cmp_files = (("left", b"a\nX\xff"), ("right", b"a\nY\0"))
    for name, flags in (("first", ()), ("verbose", ("-l",)),
                        ("print-bytes", ("-b",)), ("verbose-bytes", ("-lb",)),
                        ("quiet", ("-s",)), ("limit", ("-n", "2")),
                        ("skip", ("-i", "2"))):
        out.append(Case("gnu", "cmp", name, (*flags, "left", "right"),
                        files=cmp_files))
    out.append(Case("gnu", "cmp", "equal", ("left", "right"),
                    files=(("left", b"a\nX"), ("right", b"a\nX"))))
    out.append(Case("gnu", "cmp", "eof", ("left", "right"),
                    files=(("left", b"a\nX"), ("right", b"a\n"))))
    out.append(Case("gnu", "cmp", "eof-verbose", ("-l", "left", "right"),
                    files=(("left", b"a\nX"), ("right", b"a\n"))))
    out.append(Case("gnu", "cmp", "positional-skip", ("left", "right", "2", "1"),
                    files=cmp_files))
    out.append(Case("gnu", "cmp", "chunk-boundary", ("left", "right"),
                    files=(("left", b"a" * (128 * 1024) + b"X"),
                           ("right", b"a" * (128 * 1024) + b"Y"))))
    out.append(Case("gnu", "cmp", "hex-limit", ("-n", "0x2", "left", "right"),
                    files=cmp_files))
    out.append(Case("gnu", "cmp", "octal-limit", ("-n", "02", "left", "right"),
                    files=cmp_files))
    out.append(Case("gnu", "cmp", "shared-stdin", ("-", "-"), stdin=b"abc\n"))
    out.append(Case("gnu", "cmp", "missing", ("missing", "left"),
                    files=cmp_files))
    out.append(Case("gnu", "cmp", "missing-quiet", ("-s", "missing", "left"),
                    files=cmp_files))
    out.append(Case("gnu", "cmp", "directory", ("left", "dir"),
                    files=cmp_files, dirs=("dir",)))
    out.append(Case("gnu", "cmp", "incompatible-modes", ("-ls", "left", "right"),
                    files=cmp_files))

    # Pure tab-stop calculation over bounded byte chunks.
    both("expand", "default", stdin=b"a\tb\n\tend\n")
    both("expand", "four-columns", ["-t", "4"], stdin=b"a\tb\tend\n")
    both("expand", "initial-only", ["-i", "-t4"],
         stdin=b" \tlead\tinner\n\tsecond\n")
    both("expand", "explicit-stops", ["--tabs=2,4"],
         stdin=b"a\tb\tc\td\n")
    both("expand", "backspace", ["-t4"], stdin=b"ab\b\tx\n")
    both("expand", "binary", ["-t4"], stdin=b"\xff\t\x80\n")
    both("expand", "long-line", ["-t4", "data"],
         files=(("data", b"a" * (64 * 1024 - 1) + b"\tend\n"),))
    out.append(Case("gnu", "expand", "unicode-width", ("-t4",),
                    "é\t中\tX\n".encode()))
    out.append(Case("gnu", "expand", "combining-width", ("-t4",),
                    "é\tx\n".encode()))
    out.append(Case("gnu", "expand", "absolute-repeat", ("--tabs=2,4,/8",),
                    b"a\tb\tc\td\n"))
    out.append(Case("gnu", "expand", "relative-repeat", ("--tabs=1,+8",),
                    b"\tX\tY\n"))
    out.append(Case("gnu", "expand", "zero-tab-width", ("-t", "0"), b"a\tb\n"))
    out.append(Case("gnu", "expand", "descending-stops", ("-t", "4,2"),
                    b"a\tb\n"))

    # Streaming space compression shares expand's tab-stop and column rules.
    both("unexpand", "default-leading", stdin=b"        x\na       b\n")
    both("unexpand", "all-four", ["-t4"], stdin=b"a   b\n        x\n")
    both("unexpand", "first-only", ["--first-only", "-t4"],
         stdin=b"    x   y\n")
    both("unexpand", "space-before-tab", ["-a"],
         stdin=b"a       \tx\na      \tx\n")
    both("unexpand", "single-space-at-stop", ["-a"],
         stdin=b"1234567 X\n1234567  X\n1234567 \tX\n")
    both("unexpand", "explicit-stops", ["-t2,4"],
         stdin=b"  x   y       z\n    \t  end\n")
    both("unexpand", "absolute-repeat", ["--tabs=2,4,/8"],
         stdin=b"  x   y       z\n")
    both("unexpand", "relative-repeat", ["--tabs=1,+8"],
         stdin=b"        x         y\n")
    both("unexpand", "backspace", ["-t4"], stdin=b"abc\b     X\n")
    both("unexpand", "binary", ["-t4"], stdin=b"\xff   \x80\n")
    both("unexpand", "chunk-boundary", ["-t4", "data"],
         files=[("data", b"x" * (64 * 1024 - 1) + b"   end\n")])
    out.append(Case("gnu", "unexpand", "unicode-width", ("-t4",),
                    "é   中  X\n".encode()))
    out.append(Case("gnu", "unexpand", "zero-tab-width", ("-t", "0"), b"a b\n"))
    out.append(Case("gnu", "unexpand", "descending-stops", ("-t", "4,2"), b"a b\n"))

    # GNU grep is a separate package from coreutils and has no uutils reference.
    grep_data = b"alpha\nbeta\nALPHA\nalphanumeric\nlast"
    for name, flags, pattern in (
        ("basic", (), "alpha"),
        ("fixed", ("-F",), "alpha"),
        ("ignore-case", ("-i",), "alpha"),
        ("invert", ("-v",), "alpha"),
        ("line-numbers", ("-n",), "alpha"),
        ("byte-offset", ("-b",), "alpha"),
        ("count", ("-c",), "alpha"),
        ("quiet", ("-q",), "alpha"),
        ("whole-line", ("-x",), "alpha"),
        ("whole-word", ("-w",), "alpha"),
        ("anchor-start", (), "^alpha"),
        ("anchor-end", (), "a$"),
        ("dot", (), "a.ph"),
        ("star", (), "alph*a"),
        ("extended-plus", ("-E",), "alph+a"),
        ("extended-alternation", ("-E",), "^alpha|beta$"),
        ("basic-alternation", (), r"^alpha\|beta$"),
        ("extended-bracket", ("-E",), "[a-c]eta"),
        ("fixed-metachar", ("-F",), "a.*"),
        ("only-matching-fixed", ("-Fo",), "alpha"),
        ("only-matching-regex", ("-Eo",), "al.*a"),
    ):
        out.append(Case("gnu", "grep", name, (*flags, pattern), grep_data))
    out.append(Case("gnu", "grep", "files", ("a", "first", "second"),
                    files=(("first", b"a\nb\n"), ("second", b"c\na\n"))))
    out.append(Case("gnu", "grep", "files-with-matches", ("-l", "a", "first", "second"),
                    files=(("first", b"a\n"), ("second", b"b\n"))))
    out.append(Case("gnu", "grep", "files-without-match", ("-L", "a", "first", "second"),
                    files=(("first", b"a\n"), ("second", b"b\n"))))
    out.append(Case("gnu", "grep", "pattern-file", ("-f", "patterns", "input"),
                    files=(("patterns", b"alpha\nbeta\n"), ("input", grep_data))))
    out.append(Case("gnu", "grep", "zero-data", ("-z", "alpha"),
                    b"alpha\0beta\0alpha"))
    out.append(Case("gnu", "grep", "fixed-chunk-crossing", ("-F", "xyz", "input"),
                    files=(("input", b"a" * (4 * 1024 * 1024 - 2) + b"xyz\n"),)))
    out.append(Case("gnu", "grep", "fixed-unterminated-tail", ("-F", "xyz", "input"),
                    files=(("input", b"a\nxyz"),)))

    # The no-backslash path in echo -e skips character-list construction.
    both("echo", "escaped-mode-without-backslash", ["-e", "café", "中🙂"])
    both("echo", "escaped-mode-with-unicode", ["-e", "café\\t中🙂"])

    both("realpath", "existing-relative", ["tree/../tree/file"],
         files=[("tree/file", b"data")])
    both("realpath", "symlink", ["alias"],
         files=[("tree/file", b"data")], links=[("alias", "tree/file")])
    both("realpath", "multiple-paths", ["first", "second"],
         files=[("first", b"1"), ("second", b"2")])
    both("realpath", "zero-delimiter", ["-z", "first", "second"],
         files=[("first", b"1"), ("second", b"2")])
    both("realpath", "canonicalize-existing", ["-e", "tree/../tree/file"],
         files=[("tree/file", b"data")])
    both("realpath", "canonicalize-missing", ["-m", "none/../future/file"])
    both("realpath", "canonicalize-missing-through-link", ["-m", "alias/future"],
         dirs=["tree"], links=[("alias", "tree")])
    both("realpath", "no-symlinks", ["-s", "alias"],
         files=[("target", b"data")], links=[("alias", "target")])
    both("realpath", "missing-default", ["absent"])
    both("realpath", "leading-dash-operand", ["--", "-file"],
         files=[("-file", b"data")])

    both("pwd", "physical-path", ["-P"])
    both("pwd", "logical-path", ["-L"])
    both("printenv", "known-variable", ["LC_ALL"])
    both("printenv", "several-variables", ["LC_ALL", "TZ"])
    both("printenv", "missing-variable", ["LUTILS_UNSET_VARIABLE_9E4B"])

    # rev belongs to util-linux. The other implemented stream generator, yes,
    # is bounded by the executor's prefix mode so it cannot run indefinitely.
    for name, args, data, files in [
        ("empty-input", (), b"", ()),
        ("several-lines", (), b"abc\n12345\n", ()),
        ("unterminated-line", (), b"abc\nxyz", ()),
        ("blank-line", (), b"one\n\ntwo\n", ()),
        ("tabs-and-spaces", (), b"a\tb c\n", ()),
        ("file-operand", ("input",), b"", (("input", b"abc\nxyz"),)),
        ("several-files", ("first", "second"), b"",
         (("first", b"abc\n"), ("second", b"123\n"))),
    ]:
        out.append(Case("behavior", "rev", name, args, data, files,
                        reference="util-linux"))
    # util-linux rev interprets multibyte input as characters in a UTF-8 locale.
    # Restrict this case because C rev rejects those bytes before reversal.
    out.append(Case("behavior", "rev", "unicode-characters",
                    stdin="é中🙂\nnaïve".encode(),
                    reference="util-linux", locales=("C.UTF-8",)))

    for name, args, limit in [
        ("default", (), 12),
        ("single-word", ("ok",), 15),
        ("multiple-words", ("one", "two"), 16),
        ("empty-word", ("",), 8),
        ("literal-option-after-separator", ("--", "-n"), 12),
        ("across-buffer-boundary", ("x",), 520),
    ]:
        both("yes", name, args, output_limit=limit)

    return out
