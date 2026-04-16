{
  description = "aski — delimiter-typed language, synth-driven compiler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";

    aski-core-src = { url = "github:LiGoldragon/aski-core"; flake = false; };

    # Bootstrap compiler — askic-bootstrap branch
    aski-rs-bootstrap-src = {
      url = "github:LiGoldragon/aski-rs/askic-bootstrap";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, fenix, crane, aski-core-src, aski-rs-bootstrap-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        toolchain = fenix.packages.${system}.stable.toolchain;
        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

        bootstrapSrc = pkgs.lib.cleanSourceWith {
          src = aski-rs-bootstrap-src;
          filter = path: type:
            (craneLib.filterCargoSources path type) ||
            (builtins.match ".*\\.aski$" path != null) ||
            (builtins.match ".*\\.synth$" path != null);
        };

        bootstrap-commonArgs = {
          pname = "askic";
          version = "0.15.0";
          src = bootstrapSrc;
        };

        cargoArtifacts = craneLib.buildDepsOnly bootstrap-commonArgs;

        askic = craneLib.buildPackage (bootstrap-commonArgs // {
          inherit cargoArtifacts;
        });

        synth-dir = "${aski-core-src}/source";

        # ── Roundtrip test ─────────────────────────────
        roundtrip-test = import "${aski-rs-bootstrap-src}/tests/roundtrip.nix" {
          inherit pkgs aski-core-src;
          askic = askic;
          rustc = toolchain;
        };

        editor = import ./nix/editor.nix { inherit pkgs; };

      in {
        packages = {
          default = askic;
          inherit askic;
          inherit (editor) tree-sitter-aski tree-sitter-aski-wasm aski-mode aski-ts-mode;
        };

        checks = {
          # Unit tests pass
          askic-tests = craneLib.cargoTest (bootstrap-commonArgs // {
            inherit cargoArtifacts;
          });

          # Generated Rust compiles with rustc
          roundtrip = roundtrip-test;
        };

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};
          packages = with pkgs; [ rust-analyzer ];
        };
      }
    );
}
