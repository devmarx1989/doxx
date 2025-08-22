{
  description = "doxx: Terminal .docx viewer (built with naersk)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nmattia/naersk";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    naersk,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        # Use naersk with the nixpkgs toolchain
        naerskLib = naersk.lib.${system}.override {
          cargo = pkgs.cargo;
          rustc = pkgs.rustc;
        };

        nativeBuildInputs = [pkgs.pkg-config];
        buildInputs = [
          # Add system libs here if you pull in crates that need them, e.g.:
          # pkgs.openssl pkgs.zlib pkgs.libxkbcommon pkgs.wayland
        ];
      in rec {
        packages.default = naerskLib.buildPackage {
          pname = "doxx";
          src = ./.;

          inherit nativeBuildInputs buildInputs;

          # naersk builds in --release by default; don't add it again.
          # cargoBuildOptions = x: x ++ [ "--release" ];

          doCheck = false;

          meta = with pkgs.lib; {
            description = "Terminal document viewer for .docx files";
            homepage = "https://github.com/bgreenwell/doxx";
            license = licenses.mit;
            mainProgram = "doxx";
            maintainers = [];
            platforms = platforms.linux;
          };
        };

        apps.default = {
          type = "app";
          program = "${packages.default}/bin/doxx";
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.cargo
            pkgs.rustc
            pkgs.clippy
            pkgs.rustfmt
          ];
          buildInputs = buildInputs;
          shellHook = ''
            echo "→ devShell ready. Try: cargo build --release"
          '';
        };
      }
    );
}
