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

        # naersk with the toolchain we want.
        naerskLib = naersk.lib.${system}.override {
          cargo = pkgs.cargo;
          rustc = pkgs.rustc;
        };

        # Common native/system deps (kept minimal; adjust if you add crates that need more)
        nativeBuildInputs = [pkgs.pkg-config];
        buildInputs = [
          # Add libs here if you later pull in crates that need them, e.g.:
          # pkgs.openssl
          # pkgs.zlib
          # pkgs.libxkbcommon
          # pkgs.wayland
        ];
      in rec {
        packages.default = naerskLib.buildPackage {
          pname = "doxx";
          # Version is taken from Cargo.toml by naersk; you can also pin it:
          # version = "0.1.0";
          src = ./.;

          inherit nativeBuildInputs buildInputs;

          # Helpful for smaller binaries in release builds
          cargoBuildOptions = x: x ++ ["--release"];
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

        # `nix run` convenience
        apps.default = {
          type = "app";
          program = "${packages.default}/bin/doxx";
        };

        # Dev shell with a basic Rust toolchain and common helpers
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
