{ pkgs }:
let
  lib = pkgs.lib;
  revisions = {
    gnu = "83545af2a876fc9653dcd984e5f8eeef05711661";
    uutils = "5dd33b8c704b6115f727cb84a94728b3e74faca8";
    netbsd = "f173a420531ac49d9763be6cb5c1aaadb63212c9";
    freebsd = "1fb5d8265bc4bbbf1f5bc79cc1d2a7f280b446b2";
  };
  repositories = {
    gnu = "coreutils/coreutils";
    uutils = "uutils/coreutils";
    netbsd = "NetBSD/src";
    freebsd = "freebsd/freebsd-src";
  };
  files = {
    gnu = {
      "COPYING" = "sha256-OXLcl0T2SZ8Pmy2/dmlvKuetivmyPd5m1q+Gyd+zaYY=";
      "tests/Coreutils.pm" = "sha256-+pJte1sk2vu/O7jyHL+ok2wxGo4hxj8lc2Pl4+j8AXc=";
      "tests/CuSkip.pm" = "sha256-NHUTyuSmkVAzt/qRHJ1ajdTx3lLv2Y4qTp2ssb+FyUI=";
      "tests/head/head.pl" = "sha256-V1TBmF1ePKkQfV1JSF3pVZDViLOMQAAQVXJRBh0Ki/w=";
      "tests/misc/basename.pl" = "sha256-Ck1JICLj2/x8j4pGsvDKcTnbMJijWc54d1XKo4Zf1RE=";
      "tests/misc/dirname.pl" = "sha256-GaN7v2IUg1sdLx+24SfQBO2xcwxmDN+DTA3cb5q6iLU=";
      "tests/seq/seq.pl" = "sha256-0ntIznmc6+nEpWB0vfe0Y7JPpxbcbyw0oibdLae/XIY=";
    };
    uutils = {
      "LICENSE" = "sha256-KZU0Beqj3MQcN9FiHVW2pH7uk+BWE+Q55zKVApdAsQw=";
      "tests/by-util/test_basename.rs" = "sha256-KSBP85VzG51dWLMTWWv5LIhfD3M1Mf1IsUe9gIVvNsQ=";
      "tests/by-util/test_dirname.rs" = "sha256-5W7bbIIMJhzwNYZdHs/VPErzR2526agPxgGx+fWK10I=";
      "tests/by-util/test_echo.rs" = "sha256-9WjRmtGy/sXoV2VRhKsNpz1+n7y4yv7kofPTzmieVNE=";
      "tests/by-util/test_seq.rs" = "sha256-TbHkcBBAT/PieOfEdPvX8XsjQ2DsZVGDzC2gmaaOjb0=";
    };
    netbsd = {
      "tests/bin/cat/d_align.in" = "sha256-Z/gvYDnBFPwvYlv+AMcxLBmITps2DWjuDxz3Ey96vFk=";
      "tests/bin/cat/d_align.out" = "sha256-o+CJXQ2kNGBnW+VkPLHuQKh+nl6K9u3QqjkYYwJAcaM=";
      "tests/bin/cat/d_se_output.in" = "sha256-u1WOSJ6NgdFmi4Ck/HVIaU8/vwGIsU+xVys2vWgUgNo=";
      "tests/bin/cat/d_se_output.out" = "sha256-64i5ZcgReATfPRRWks8UH9g/i/W9NiZ6RCbP63f/RYg=";
      "tests/bin/cat/t_cat.sh" = "sha256-Mo8m5HUFzHrl/ShJtEeDFq45J8CSEX6S7ecgCitmyEE=";
      "tests/bin/cp/t_cp.sh" = "sha256-9orazFR3Qht1bs7dxWQVMNCPh0QfMc5O6c+jLDVXNFY=";
      "tests/bin/sleep/t_sleep.sh" = "sha256-s+jLN5gcgEyChQv6yLTA03xUUD00HdqG9tbQHNm4ozQ=";
      "tests/usr.bin/basename/t_basename.sh" = "sha256-cA0GWkWnPF67On3K0SPbiAAyshx0SVx2oBmggJgZ7Jo=";
      "tests/usr.bin/cut/d_basic.out" = "sha256-6Y2a2kOolNlm0mL2MO/qKv5loqUeGWHzVCCm8tPlrHU=";
      "tests/usr.bin/cut/d_cut.in" = "sha256-iDvTRt9aSDwal4aEosFfYUkkfxhVnim3efJh2EdwFxI=";
      "tests/usr.bin/cut/t_cut.sh" = "sha256-vtAYGLZzf2x7ub+0dVntu4DCGYbA+Ei9e2LymPylXkY=";
      "tests/usr.bin/dirname/t_dirname.sh" = "sha256-F1vmpNZS5RcYDLQMsP5ZgQlThC6IzPUESBdyl/DwZvo=";
      "tests/usr.bin/find/t_find.sh" = "sha256-NrYiwFp8tNQ+bnUlc6Uyygx+ZS3SpPDF5h8ku3JH97M=";
    };
    freebsd = {
      "bin/cat/tests/cat_extra_test.sh" = "sha256-6anNcyh9vWLchhMr+01kgK2MJkcA5pY7mHza1hD2WjY=";
      "bin/cp/tests/cp_test.sh" = "sha256-2hjiBoGj+3qcxMZovtUfcSIkI9yNHVcaWpEpC5TNYqU=";
      "bin/ls/tests/ls_tests.sh" = "sha256-jfZotG5ljtW7SNmxR4FRnlnaGpNoUmpKbmdRfPTZtNU=";
      "bin/rm/tests/rm_test.sh" = "sha256-+jMhjItRg6GLO3LUAWHF9taFh/ZPnF0mDKGu6ikvud8=";
      "usr.bin/head/tests/head_test.sh" = "sha256-7cFIXwPLTYUF9fZ872w4+xIETcgY8P1+93NQOMEliWc=";
      "usr.bin/seq/tests/seq_test.sh" = "sha256-31v9X/fWO9z0nqjLyygiHAi8Qgje//i6KTR/r0x2xYI=";
      "usr.bin/tail/tests/tail_test.sh" = "sha256-4lo0Hv3X66AKB5RiA/prtCYOFzyXg8IGG1fnS2OPVno=";
    };
  };
  entries = lib.concatLists (lib.mapAttrsToList (family: paths:
    lib.mapAttrsToList (path: hash: { inherit family path hash; }) paths) files);
in pkgs.runCommand "lutils-test-sources" { } (lib.concatMapStringsSep "\n" (entry: let
  source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/${repositories.${entry.family}}/${revisions.${entry.family}}/${entry.path}";
    hash = entry.hash;
  };
in ''
  install -D -m 444 ${source} "$out/${entry.family}/${entry.path}"
'') entries)
