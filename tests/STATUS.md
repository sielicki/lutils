# Utility test status

Generated 2026-11-01 01:03 UTC with `nix develop --command uv run tests/report.py --output tests/STATUS.md`.

**2141/2503 checks pass.** Coverage: 168/168 distinct utilities have tests; 45/45 implemented utilities have tests. The table includes all 172 project and utility rows tracked in the README.

The expanded corpus has 2458 executions but only 1480 distinct test configurations after collapsing source-family duplicates while retaining locale variants. The eight utilities with the most passing checks account for 732/2141 passes: `basename` (122), `tail` (108), `wc` (97), `dirname` (97), `sort` (92), `basenc` (80), `uniq` (68), `sha256sum` (68).

Reference-backed corpus cases run under both C and C.UTF-8. Literal expectations, imported uutils cases, and GNU Perl suites run in C.

Corpus checks by locale: `C` 1063/1246, `C.UTF-8` 1033/1212.

GNU and uutils agree on 967/974 shared corpus inputs. This is reference agreement, not `lutils` conformance.

Reference disagreements: `mkdir/existing-without-parents` [C], `mkdir/existing-without-parents` [C.UTF-8], `mkdir/parent-is-file` [C], `mkdir/parent-is-file` [C.UTF-8], `wc/unicode-character-count` [C], `wc/unicode-display-width` [C], `wc/unicode-word-separator` [C].

The four GNU Perl suites executed 198 named subcases (`basename` 35, `dirname` 22, `head` 63, `seq` 78). They count as four suite checks in the headline.

Curated behavioral cases add 759 executions across 50 utilities. 107 utilities still have only a baseline case; these rows indicate test reach, not deep conformance. Privileged and interactive commands need isolated system fixtures before positive paths can be checked.

Each cell is passed/total. `—` means no test in that source. An imported check is a ported uutils case; a GNU suite counts as one suite check. The same utility appears in multiple project rows with the same test counts; the headline counts each check once. Failures from stubs are expected.

| Project    | Utility      | Implemented   | GNU   | uutils   | NetBSD   | FreeBSD   | Behavior   | Basic   | Imported   | GNU suite   | Total   | Result   |
|------------|--------------|---------------|-------|----------|----------|-----------|------------|---------|------------|-------------|---------|----------|
| Coreutils  | `[`          | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `arch`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `b2sum`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `base32`     | Yes           | 26/26 | 22/22    | —        | —         | —          | —       | —          | —           | 48/48   | Passing  |
| Coreutils  | `base64`     | Yes           | 28/28 | 24/24    | —        | —         | —          | —       | —          | —           | 52/52   | Passing  |
| Coreutils  | `basename`   | Yes           | 48/48 | 48/48    | 12/12    | —         | —          | —       | 13/13      | 1/1         | 122/122 | Passing  |
| Coreutils  | `basenc`     | Yes           | 40/40 | 40/40    | —        | —         | —          | —       | —          | —           | 80/80   | Passing  |
| Coreutils  | `cat`        | Yes           | 24/24 | 24/24    | 1/2      | —         | —          | —       | —          | —           | 49/50   | Failing  |
| Coreutils  | `chgrp`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `chmod`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `chown`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `chroot`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `cksum`      | Yes           | 26/26 | 26/26    | —        | —         | —          | —       | —          | —           | 52/52   | Passing  |
| Coreutils  | `comm`       | Yes           | 30/30 | 28/28    | —        | —         | 4/4        | —       | —          | —           | 62/62   | Passing  |
| Coreutils  | `cp`         | Yes           | 18/24 | 18/24    | —        | —         | —          | —       | —          | —           | 36/48   | Failing  |
| Coreutils  | `csplit`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `cut`        | Yes           | 36/36 | 30/30    | —        | —         | —          | —       | —          | —           | 66/66   | Passing  |
| Coreutils  | `date`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `dd`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `df`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `dir`        | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `dircolors`  | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `dirname`    | Yes           | 38/38 | 38/38    | 9/9      | —         | —          | —       | 11/11      | 1/1         | 97/97   | Passing  |
| Coreutils  | `du`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `echo`       | Yes           | 22/24 | 22/24    | —        | —         | —          | —       | 12/12      | —           | 56/60   | Failing  |
| Coreutils  | `env`        | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `expand`     | Yes           | 26/26 | 14/14    | —        | —         | —          | —       | —          | —           | 40/40   | Passing  |
| Coreutils  | `expr`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `factor`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `false`      | Yes           | 2/2   | 2/2      | —        | —         | —          | —       | —          | —           | 4/4     | Passing  |
| Coreutils  | `fmt`        | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `fold`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `groups`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `head`       | Yes           | 28/28 | 28/28    | —        | 7/7       | —          | —       | —          | 1/1         | 64/64   | Passing  |
| Coreutils  | `hostid`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `hostname`   | No            | —     | —        | —        | —         | 0/2        | —       | —          | —           | 0/2     | Failing  |
| Coreutils  | `id`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `install`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `join`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `kill`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `link`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `ln`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `logname`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `ls`         | Yes           | 26/28 | 26/28    | —        | —         | —          | —       | —          | —           | 52/56   | Failing  |
| Coreutils  | `md5sum`     | Yes           | 32/32 | 32/32    | —        | —         | —          | —       | —          | —           | 64/64   | Passing  |
| Coreutils  | `mkdir`      | Yes           | 15/20 | 14/20    | —        | —         | —          | —       | —          | —           | 29/40   | Failing  |
| Coreutils  | `mkfifo`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `mknod`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `mktemp`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `more`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `mv`         | Yes           | 16/20 | 16/20    | —        | —         | —          | —       | —          | —           | 32/40   | Failing  |
| Coreutils  | `nice`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `nl`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `nohup`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `nproc`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `numfmt`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `od`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `paste`      | Yes           | 30/30 | 20/20    | —        | —         | —          | —       | —          | —           | 50/50   | Passing  |
| Coreutils  | `pathchk`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `pinky`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `pr`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `printenv`   | Yes           | 6/6   | 6/6      | —        | —         | —          | —       | —          | —           | 12/12   | Passing  |
| Coreutils  | `printf`     | No            | 0/2   | 0/2      | —        | —         | —          | —       | —          | —           | 0/4     | Failing  |
| Coreutils  | `ptx`        | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `pwd`        | Yes           | 2/4   | 2/4      | —        | —         | —          | —       | —          | —           | 4/8     | Failing  |
| Coreutils  | `readlink`   | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `realpath`   | Yes           | 16/20 | 16/20    | —        | —         | —          | —       | —          | —           | 32/40   | Failing  |
| Coreutils  | `rm`         | Yes           | 24/24 | 24/24    | —        | —         | —          | —       | —          | —           | 48/48   | Passing  |
| Coreutils  | `rmdir`      | Yes           | 2/2   | 2/2      | —        | —         | —          | —       | —          | —           | 4/4     | Passing  |
| Coreutils  | `seq`        | Yes           | 18/18 | 18/18    | —        | 0/1       | —          | —       | 5/5        | 1/1         | 42/43   | Failing  |
| Coreutils  | `sha1sum`    | Yes           | 28/28 | 28/28    | —        | —         | —          | —       | —          | —           | 56/56   | Passing  |
| Coreutils  | `sha224sum`  | Yes           | 28/28 | 28/28    | —        | —         | —          | —       | —          | —           | 56/56   | Passing  |
| Coreutils  | `sha256sum`  | Yes           | 34/34 | 34/34    | —        | —         | —          | —       | —          | —           | 68/68   | Passing  |
| Coreutils  | `sha384sum`  | Yes           | 28/28 | 28/28    | —        | —         | —          | —       | —          | —           | 56/56   | Passing  |
| Coreutils  | `sha512sum`  | Yes           | 28/28 | 28/28    | —        | —         | —          | —       | —          | —           | 56/56   | Passing  |
| Coreutils  | `shred`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `shuf`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `sleep`      | Yes           | 2/2   | 2/2      | —        | —         | 2/2        | —       | —          | —           | 6/6     | Passing  |
| Coreutils  | `sort`       | Yes           | 46/46 | 46/46    | —        | —         | —          | —       | —          | —           | 92/92   | Passing  |
| Coreutils  | `split`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `stat`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `stdbuf`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `stty`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `sum`        | Yes           | 8/8   | 8/8      | —        | —         | —          | —       | —          | —           | 16/16   | Passing  |
| Coreutils  | `sync`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `tac`        | Yes           | 4/4   | 4/4      | —        | —         | —          | —       | —          | —           | 8/8     | Passing  |
| Coreutils  | `tail`       | Yes           | 52/52 | 52/52    | —        | 4/4       | —          | —       | —          | —           | 108/108 | Passing  |
| Coreutils  | `tee`        | Yes           | 4/4   | 4/4      | —        | —         | —          | —       | —          | —           | 8/8     | Passing  |
| Coreutils  | `test`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `timeout`    | No            | —     | —        | —        | —         | 0/4        | —       | —          | —           | 0/4     | Failing  |
| Coreutils  | `touch`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `tr`         | Yes           | 30/30 | 26/26    | —        | —         | —          | —       | —          | —           | 56/56   | Passing  |
| Coreutils  | `true`       | Yes           | 2/2   | 2/2      | —        | —         | —          | —       | —          | —           | 4/4     | Passing  |
| Coreutils  | `truncate`   | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `tsort`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `tty`        | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `uname`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `unexpand`   | Yes           | 28/28 | 22/22    | —        | —         | —          | —       | —          | —           | 50/50   | Passing  |
| Coreutils  | `uniq`       | Yes           | 34/34 | 34/34    | —        | —         | —          | —       | —          | —           | 68/68   | Passing  |
| Coreutils  | `unlink`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `uptime`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `users`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `vdir`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `wc`         | Yes           | 50/50 | 47/50    | —        | —         | —          | —       | —          | —           | 97/100  | Failing  |
| Coreutils  | `who`        | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `whoami`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Coreutils  | `yes`        | Yes           | 12/12 | 12/12    | —        | —         | —          | —       | —          | —           | 24/24   | Passing  |
| Findutils  | `find`       | No            | 0/6   | —        | —        | —         | 0/12       | —       | —          | —           | 0/18    | Failing  |
| Findutils  | `locate`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Findutils  | `updatedb`   | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Findutils  | `xargs`      | No            | 0/4   | —        | —        | —         | 0/8        | —       | —          | —           | 0/12    | Failing  |
| Diffutils  | `cmp`        | Yes           | 38/38 | —        | —        | —         | 4/4        | —       | —          | —           | 42/42   | Passing  |
| Diffutils  | `diff`       | No            | 0/4   | —        | —        | —         | 0/6        | —       | —          | —           | 0/10    | Failing  |
| Diffutils  | `diff3`      | No            | —     | —        | —        | —         | 0/4        | —       | —          | —           | 0/4     | Failing  |
| Diffutils  | `sdiff`      | No            | —     | —        | —        | —         | 0/2        | —       | —          | —           | 0/2     | Failing  |
| Util-linux | `blockdev`   | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `cal`        | No            | —     | —        | —        | —         | 0/2        | —       | —          | —           | 0/2     | Failing  |
| Util-linux | `chcpu`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `ctrlaltdel` | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `dmesg`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `fdisk`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `fsfreeze`   | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `hexdump`    | No            | —     | —        | —        | —         | 0/2        | —       | —          | —           | 0/2     | Failing  |
| Util-linux | `kill`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `last`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `lsblk`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `lscpu`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `lsipc`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `lslocks`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `lsmem`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `lsns`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `mcookie`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `mesg`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `mount`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `mountpoint` | No            | —     | —        | —        | —         | 0/2        | —       | —          | —           | 0/2     | Failing  |
| Util-linux | `nologin`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `renice`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `rev`        | Yes           | —     | —        | —        | —         | 17/17      | —       | —          | —           | 17/17   | Passing  |
| Util-linux | `setpgid`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `setsid`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `umount`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Util-linux | `uuidgen`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `free`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `hugetop`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `kill`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `pgrep`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `pidof`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `pidwait`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `pkill`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `pmap`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `ps`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `pwdx`       | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `skill`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `slabtop`    | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `snice`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `sysctl`     | No            | —     | —        | —        | —         | 0/2        | —       | —          | —           | 0/2     | Failing  |
| Procps     | `tload`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `top`        | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `uptime`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `vmstat`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `w`          | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Procps     | `watch`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Sed        | `sed`        | No            | 0/6   | —        | —        | —         | 0/10       | —       | —          | —           | 0/16    | Failing  |
| Tar        | `tar`        | No            | —     | —        | —        | —         | 0/6        | —       | —          | —           | 0/6     | Failing  |
| Acl        | `chacl`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Acl        | `getfacl`    | No            | —     | —        | —        | —         | 0/2        | —       | —          | —           | 0/2     | Failing  |
| Acl        | `setfacl`    | No            | —     | —        | —        | —         | 0/4        | —       | —          | —           | 0/4     | Failing  |
| Hostname   | `hostname`   | No            | —     | —        | —        | —         | 0/2        | —       | —          | —           | 0/2     | Failing  |
| Login      | `login`      | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Login      | `newgrp`     | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Login      | `su`         | No            | —     | —        | —        | —         | —          | 0/2     | —          | —           | 0/2     | Failing  |
| Grep       | `grep`       | Yes           | 56/56 | —        | —        | —         | —          | —       | —          | —           | 56/56   | Passing  |
