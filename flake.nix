{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nmattia/naersk";
  };

  outputs = { self, nixpkgs, utils, naersk }:
    utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages."${system}";
      naersk-lib = naersk.lib."${system}";
    in rec {
      packages.kickstart = naersk-lib.buildPackage {
        pname = "kickstart";
        root = ./.;
      };
      defaultPackage = packages.kickstart;

      apps.kickstart = utils.lib.mkApp {
        drv = packages.kickstart;
        exePath = "/bin/kickstart";
      };
      apps.default = apps.kickstart;

      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [ rustc cargo clippy rustfmt rust-analyzer ];

        RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
      };
    });
}
