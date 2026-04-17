{
  description = "aski — rkyv contract types for askic↔semac";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    corec = {
      url = "github:LiGoldragon/corec";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
      inputs.crane.follows = "crane";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, fenix, crane, flake-utils, corec, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        toolchain = fenix.packages.${system}.stable.toolchain;
        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

        corec-bin = corec.packages.${system}.corec;

        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            (craneLib.filterCargoSources path type)
            || (builtins.match ".*\\.aski$" path != null);
        };

        generated = pkgs.runCommand "aski-generated" {
          nativeBuildInputs = [ corec-bin ];
        } ''
          mkdir -p generated
          corec ${./core} generated/aski.rs
          mkdir -p $out
          cp generated/aski.rs $out/
        '';

        aski-source = pkgs.runCommand "aski-source" {} ''
          cp -r ${src} $out
          chmod -R +w $out
          mkdir -p $out/generated
          cp ${generated}/aski.rs $out/generated/
        '';

        commonArgs = {
          src = aski-source;
          pname = "aski";
          version = "0.17.0";
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        aski-lib = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });

      in {
        packages = {
          default = aski-source;
          source = aski-source;
          lib = aski-lib;
          inherit generated;
        };

        checks = {
          lib-build = aski-lib;
        };

        devShells.default = craneLib.devShell {
          packages = [ corec-bin pkgs.rust-analyzer ];
        };
      }
    );
}
