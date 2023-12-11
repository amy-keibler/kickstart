{
  description = "A templating tool for creating projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nmattia/naersk";
  };

  outputs = { self, nixpkgs, flake-utils, crane, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
            let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-analyzer" "rust-src" ];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        testDataFilter = path: _type: builtins.match ".*\.[py|md|png]$" path != null;

        srcFilter = path: type:
          (testDataFilter path type) || (craneLib.filterCargoSources path type);

        src = pkgs.lib.cleanSourceWith {
          src = craneLib.path ./.;
          filter = srcFilter;
        };

        commonArgs = {
          inherit src;
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        kickstart = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });
    in rec {
      checks = {
          inherit kickstart;

          clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
          });

          doc = craneLib.cargoDoc (commonArgs // {
            inherit cargoArtifacts;
          });

          fmt = craneLib.cargoFmt (commonArgs // {
            inherit src;
          });
        };

        packages.kickstart = kickstart;
        packages.default = packages.kickstart;

        devShells.default = pkgs.mkShell {
          inputsFrom = builtins.attrValues self.checks.${system};

          packages = with pkgs; [
            rustToolchain
            cargo-edit
            cargo-expand
            cargo-insta
            cargo-msrv
            cargo-outdated

            # GitHub tooling
            gh

            # Nix tooling
            nixpkgs-fmt
          ];
        };
    });
}
