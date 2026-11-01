# lutils

Lean 4 implementations of Unix utilities in one multicall binary. Build with
`lake build lutils`, then run `.lake/build/bin/lutils APPLET [ARGS]...` or invoke
the binary through a symlink named after an applet.

`nix develop` supplies GNU coreutils, uutils coreutils, Python, and Perl for
comparison and conformance testing.

The Lake configuration requires the LLVM backend and uses full LTO with mold
to link native targets. Run `nix develop .#llvm` for Lean 4.35.0 built with
LLVM 19 using `lean4-nix`, mold, and the comparison tools. Check with
`nix develop .#llvm --command lean --features` (which prints `[LLVM]`), and
build with `lake build lutils`. The first Nix build can take tens of minutes
and substantial disk space. `nix build .#lean-llvm` also builds the toolchain.

## Source layout

Each implemented utility has a folder at `Lutils/UTILITY/Main.lean`. The
`Lutils/Shared` modules hold code used across utilities, such as path handling,
copy and remove operations, and the `head`/`tail` engine. `Lutils.lean` imports
the utility modules and defines the multicall dispatch table; `Main.lean` is
the executable entry point. Utilities tracked below but not yet implemented
also have folders with callable stubs. They are registered in the dispatch
table and `lutils --list`, so tests can invoke them now. A stub prints
`not yet implemented` and exits with status 1. Commands listed under multiple
projects share one folder; `[` uses `Lutils/Bracket`.

## Utility status

This single table tracks the current Coreutils applet list, GNU Grep, and
commands from the nine other [uutils projects](https://uutils.org/#projects)
targeted for `lutils`: Findutils, Diffutils, Util-linux, Procps, Sed, Tar,
Acl, Hostname, and Login. Each row is one utility in one project. A command can appear in
multiple projects. For the larger suites, this is a working list of current
implementations and published project examples, rather than every command the
original suite has ever provided.

“Implemented” means the command has working code beyond its stub. Coverage names
indicate available tests, including tests that currently fail while applets are
incomplete. “Basic case” is one safe reference-backed behavior or validation
check. “Behavior cases” exercise multiple inputs, observable effects, or timing
for additional utility families. The GNU/uutils corpus includes deeper cases
for implemented applets. The detailed pass counts are in
[the test status report](tests/STATUS.md).

| Project | Utility | Implemented in `lutils`? | Conformance coverage |
| --- | --- | --- | --- |
| Coreutils | `[` | No | Basic case |
| Coreutils | `arch` | No | Basic case |
| Coreutils | `b2sum` | No | Basic case |
| Coreutils | `base32` | Yes | GNU/uutils corpus |
| Coreutils | `base64` | Yes | GNU/uutils corpus |
| Coreutils | `basename` | Yes | GNU suite; uutils cases; GNU/uutils corpus; NetBSD cases |
| Coreutils | `basenc` | Yes | GNU/uutils corpus |
| Coreutils | `cat` | Yes | GNU/uutils corpus; NetBSD fixtures |
| Coreutils | `chgrp` | No | Basic case |
| Coreutils | `chmod` | No | Basic case |
| Coreutils | `chown` | No | Basic case |
| Coreutils | `chroot` | No | Basic case |
| Coreutils | `cksum` | Yes | GNU/uutils corpus |
| Coreutils | `comm` | Yes | GNU/uutils corpus |
| Coreutils | `cp` | Yes | GNU/uutils corpus |
| Coreutils | `csplit` | No | Basic case |
| Coreutils | `cut` | Yes | GNU/uutils corpus |
| Coreutils | `date` | No | Basic case |
| Coreutils | `dd` | No | Basic case |
| Coreutils | `df` | No | Basic case |
| Coreutils | `dir` | No | Basic case |
| Coreutils | `dircolors` | No | Basic case |
| Coreutils | `dirname` | Yes | GNU suite; uutils cases; GNU/uutils corpus; NetBSD cases |
| Coreutils | `du` | No | Basic case |
| Coreutils | `echo` | Yes | uutils cases; GNU/uutils corpus |
| Coreutils | `env` | No | Basic case |
| Coreutils | `expand` | Yes | GNU/uutils corpus |
| Coreutils | `expr` | No | Basic case |
| Coreutils | `factor` | No | Basic case |
| Coreutils | `false` | Yes | GNU/uutils corpus |
| Coreutils | `fmt` | No | Basic case |
| Coreutils | `fold` | No | Basic case |
| Coreutils | `groups` | No | Basic case |
| Coreutils | `head` | Yes | GNU suite; GNU/uutils corpus; FreeBSD cases |
| Coreutils | `hostid` | No | Basic case |
| Coreutils | `hostname` | No | Behavior cases |
| Coreutils | `id` | No | Basic case |
| Coreutils | `install` | No | Basic case |
| Coreutils | `join` | No | Basic case |
| Coreutils | `kill` | No | Basic case |
| Coreutils | `link` | No | Basic case |
| Coreutils | `ln` | No | Basic case |
| Coreutils | `logname` | No | Basic case |
| Coreutils | `ls` | Yes | GNU/uutils corpus |
| Coreutils | `md5sum` | Yes | GNU/uutils corpus |
| Coreutils | `mkdir` | Yes | GNU/uutils corpus |
| Coreutils | `mkfifo` | No | Basic case |
| Coreutils | `mknod` | No | Basic case |
| Coreutils | `mktemp` | No | Basic case |
| Coreutils | `more` | No | Basic case |
| Coreutils | `mv` | Yes | GNU/uutils corpus |
| Coreutils | `nice` | No | Basic case |
| Coreutils | `nl` | No | Basic case |
| Coreutils | `nohup` | No | Basic case |
| Coreutils | `nproc` | No | Basic case |
| Coreutils | `numfmt` | No | Basic case |
| Coreutils | `od` | No | Basic case |
| Coreutils | `paste` | Yes | GNU/uutils corpus |
| Coreutils | `pathchk` | No | Basic case |
| Coreutils | `pinky` | No | Basic case |
| Coreutils | `pr` | No | Basic case |
| Coreutils | `printenv` | Yes | GNU/uutils corpus |
| Coreutils | `printf` | No | GNU/uutils corpus |
| Coreutils | `ptx` | No | Basic case |
| Coreutils | `pwd` | Yes | GNU/uutils corpus |
| Coreutils | `readlink` | No | Basic case |
| Coreutils | `realpath` | Yes | GNU/uutils corpus |
| Coreutils | `rm` | Yes | GNU/uutils corpus |
| Coreutils | `rmdir` | Yes | GNU/uutils corpus |
| Coreutils | `seq` | Yes | GNU suite; uutils cases; GNU/uutils corpus; FreeBSD case |
| Coreutils | `sha1sum` | Yes | GNU/uutils corpus |
| Coreutils | `sha224sum` | Yes | GNU/uutils corpus |
| Coreutils | `sha256sum` | Yes | GNU/uutils corpus |
| Coreutils | `sha384sum` | Yes | GNU/uutils corpus |
| Coreutils | `sha512sum` | Yes | GNU/uutils corpus |
| Coreutils | `shred` | No | Basic case |
| Coreutils | `shuf` | No | Basic case |
| Coreutils | `sleep` | Yes | GNU/uutils corpus; Behavior cases |
| Coreutils | `sort` | Yes | GNU/uutils corpus |
| Coreutils | `split` | No | Basic case |
| Coreutils | `stat` | No | Basic case |
| Coreutils | `stdbuf` | No | Basic case |
| Coreutils | `stty` | No | Basic case |
| Coreutils | `sum` | Yes | GNU/uutils corpus |
| Coreutils | `sync` | No | Basic case |
| Coreutils | `tac` | Yes | GNU/uutils corpus |
| Coreutils | `tail` | Yes | GNU/uutils corpus; FreeBSD cases |
| Coreutils | `tee` | Yes | GNU/uutils corpus |
| Coreutils | `test` | No | Basic case |
| Coreutils | `timeout` | No | Behavior cases |
| Coreutils | `touch` | No | Basic case |
| Coreutils | `tr` | Yes | GNU/uutils corpus |
| Coreutils | `true` | Yes | GNU/uutils corpus |
| Coreutils | `truncate` | No | Basic case |
| Coreutils | `tsort` | No | Basic case |
| Coreutils | `tty` | No | Basic case |
| Coreutils | `uname` | No | Basic case |
| Coreutils | `unexpand` | Yes | GNU/uutils corpus |
| Coreutils | `uniq` | Yes | GNU/uutils corpus |
| Coreutils | `unlink` | No | Basic case |
| Coreutils | `uptime` | No | Basic case |
| Coreutils | `users` | No | Basic case |
| Coreutils | `vdir` | No | Basic case |
| Coreutils | `wc` | Yes | GNU/uutils corpus |
| Coreutils | `who` | No | Basic case |
| Coreutils | `whoami` | No | Basic case |
| Coreutils | `yes` | Yes | GNU/uutils corpus |
| Findutils | `find` | No | GNU corpus; Behavior cases |
| Findutils | `locate` | No | Basic case |
| Findutils | `updatedb` | No | Basic case |
| Findutils | `xargs` | No | GNU corpus; Behavior cases |
| Diffutils | `cmp` | Yes | GNU corpus; Behavior cases |
| Diffutils | `diff` | No | GNU corpus; Behavior cases |
| Diffutils | `diff3` | No | Behavior cases |
| Diffutils | `sdiff` | No | Behavior cases |
| Util-linux | `blockdev` | No | Basic case |
| Util-linux | `cal` | No | Behavior cases |
| Util-linux | `chcpu` | No | Basic case |
| Util-linux | `ctrlaltdel` | No | Basic case |
| Util-linux | `dmesg` | No | Basic case |
| Util-linux | `fdisk` | No | Basic case |
| Util-linux | `fsfreeze` | No | Basic case |
| Util-linux | `hexdump` | No | Behavior cases |
| Util-linux | `kill` | No | Basic case |
| Util-linux | `last` | No | Basic case |
| Util-linux | `lsblk` | No | Basic case |
| Util-linux | `lscpu` | No | Basic case |
| Util-linux | `lsipc` | No | Basic case |
| Util-linux | `lslocks` | No | Basic case |
| Util-linux | `lsmem` | No | Basic case |
| Util-linux | `lsns` | No | Basic case |
| Util-linux | `mcookie` | No | Basic case |
| Util-linux | `mesg` | No | Basic case |
| Util-linux | `mount` | No | Basic case |
| Util-linux | `mountpoint` | No | Behavior cases |
| Util-linux | `nologin` | No | Basic case |
| Util-linux | `renice` | No | Basic case |
| Util-linux | `rev` | Yes | Behavior cases |
| Util-linux | `setpgid` | No | Basic case |
| Util-linux | `setsid` | No | Basic case |
| Util-linux | `umount` | No | Basic case |
| Util-linux | `uuidgen` | No | Basic case |
| Procps | `free` | No | Basic case |
| Procps | `hugetop` | No | Basic case |
| Procps | `kill` | No | Basic case |
| Procps | `pgrep` | No | Basic case |
| Procps | `pidof` | No | Basic case |
| Procps | `pidwait` | No | Basic case |
| Procps | `pkill` | No | Basic case |
| Procps | `pmap` | No | Basic case |
| Procps | `ps` | No | Basic case |
| Procps | `pwdx` | No | Basic case |
| Procps | `skill` | No | Basic case |
| Procps | `slabtop` | No | Basic case |
| Procps | `snice` | No | Basic case |
| Procps | `sysctl` | No | Behavior cases |
| Procps | `tload` | No | Basic case |
| Procps | `top` | No | Basic case |
| Procps | `uptime` | No | Basic case |
| Procps | `vmstat` | No | Basic case |
| Procps | `w` | No | Basic case |
| Procps | `watch` | No | Basic case |
| Sed | `sed` | No | GNU corpus; Behavior cases |
| Tar | `tar` | No | Behavior cases |
| Acl | `chacl` | No | Basic case |
| Acl | `getfacl` | No | Behavior cases |
| Acl | `setfacl` | No | Behavior cases |
| Hostname | `hostname` | No | Behavior cases |
| Login | `login` | No | Basic case |
| Login | `newgrp` | No | Basic case |
| Login | `su` | No | Basic case |
| Grep | `grep` | Yes | GNU corpus |

`grep` currently supports streaming fixed-string search and a byte-oriented
BRE/ERE subset (anchors, dot, brackets, repetition, and top-level alternation),
plus common selection and output flags. Grouping, back-references, interval
repetition, PCRE, recursive traversal, binary-file policy, and locale-aware
case folding remain outside the implemented subset.

Run `nix develop --command python3 tests/conformance.py` for the expanded
corpus, or `nix develop --command uv run tests/performance.py` for benchmarks. See
[tests/README.md](tests/README.md) for their provenance and runner options.
