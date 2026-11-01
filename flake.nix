{
  description = "lutils development and conformance shell";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  inputs.lean4-nix.url = "github:lenianiva/lean4-nix";
  inputs.lean4-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, lean4-nix, ... }:
    let
      forSystems = f: builtins.mapAttrs (_system: pkgs: f pkgs) nixpkgs.legacyPackages;
      # Match lean-toolchain; Lean 4.35.0 requires LLVM 19 for its LLVM backend.
      leanManifest = import "${lean4-nix}/manifests/v4.35.0.nix";
      leanLLVMOverlay = lean4-nix.readRev (leanManifest // {
        # Preserve the manifest's argument signature for callPackage.
        bootstrap = nixpkgs.lib.setFunctionArgs
          (args: leanManifest.bootstrap (args // {
            stdenv = args.pkgs.llvmPackages_19.stdenv;
            llvmPackages = args.pkgs.llvmPackages_19;
            extraCMakeFlags = [
              "-DLLVM=ON"
              "-DLLVM_CONFIG=${args.pkgs.llvmPackages_19.llvm.dev}/bin/llvm-config"
            ];
          }))
          (builtins.functionArgs leanManifest.bootstrap);
      });
      leanLLVMFor = pkgs:
        let
          leanAll = (pkgs.extend leanLLVMOverlay).lean.lean-all;
          # lean4-nix omits Lean's runtime_bc CMake target; `lean -b` needs its output.
          runtimeBC = pkgs.runCommand "lean-runtime-bc" {
            nativeBuildInputs = [ pkgs.llvmPackages_19.clang ];
          } ''
            sed -e 's/static inline/__attribute__((always_inline))/g' \
              -e '/#pragma once/d' ${leanAll}/include/lean/lean.h > lean_inlines.c
            clang -DNDEBUG -I${leanAll}/include -fPIC -c -emit-llvm lean_inlines.c -o lean.h.bc
            mkdir -p $out/lib/lean
            cp lean.h.bc $out/lib/lean/lean.h.bc
          '';
        in pkgs.runCommand "lean-llvm-4.35.0" {} ''
          mkdir -p $out
          cp -a ${leanAll}/. $out/
          chmod u+w $out/lib/lean
          ln -s ${runtimeBC}/lib/lean/lean.h.bc $out/lib/lean/lean.h.bc
        '';
    in {
    packages = forSystems (pkgs: {
      test-sources = import ./nix/test-sources.nix { inherit pkgs; };
      lean-llvm = leanLLVMFor pkgs;
    });
    devShells = forSystems (pkgs:
      let
        shell = {
          LUTILS_TEST_SOURCES = import ./nix/test-sources.nix { inherit pkgs; };
          LUTILS_GNU_BIN = "${pkgs.coreutils}/bin";
          LUTILS_UUTILS_BIN = "${pkgs.uutils-coreutils}/bin";
          LUTILS_FINDUTILS_BIN = "${pkgs.findutils}/bin";
          LUTILS_DIFFUTILS_BIN = "${pkgs.diffutils}/bin";
          LUTILS_SED_BIN = "${pkgs.gnused}/bin";
          LUTILS_GREP_BIN = "${pkgs.gnugrep}/bin";
          LUTILS_UTIL_LINUX_BIN = "${pkgs.util-linux}/bin";
          LUTILS_PROCPS_BIN = "${pkgs.procps}/bin";
          LUTILS_UUTILS_PROCPS_BIN = "${pkgs.uutils-procps}/bin";
          LUTILS_ACL_BIN = "${pkgs.acl}/bin";
          LUTILS_HOSTNAME_BIN = "${pkgs.hostname}/bin";
          LUTILS_SHADOW_BIN = "${pkgs.shadow}/bin";
          LUTILS_SU_BIN = "${pkgs.shadow.su}/bin";
          LUTILS_TAR_BIN = "${pkgs.gnutar}/bin";
          LUTILS_PLOCATE_BIN = "${pkgs.plocate}/bin";
          packages = with pkgs; [
            coreutils
            uutils-coreutils
            python3
            perl
            findutils
            diffutils
            gnused
            gnugrep
            util-linux
            procps
            uutils-procps
            acl
            hostname
            shadow
            gnutar
            plocate
          ];
        };
      in {
        default = pkgs.mkShell shell;
        llvm = pkgs.mkShell (shell // {
          # UnicodeBasic's precompiled modules use lazy resolution for C symbols
          # supplied by its aggregate library.
          hardeningDisable = [ "bindnow" ];
          LEAN_CC = "${pkgs.llvmPackages_19.clang}/bin/clang";
          packages = shell.packages ++ [ (leanLLVMFor pkgs) pkgs.llvmPackages_19.llvm pkgs.mold pkgs.cadical ];
        });
      });
  };
}
