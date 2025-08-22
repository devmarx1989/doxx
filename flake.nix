{
  description = "doxx: Terminal .docx viewer (naersk build with modern Rust)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nmattia/naersk";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    naersk,
    rust-overlay,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {inherit system overlays;};

        # Use a modern toolchain that includes std for the host target.
        # To pin: pkgs.rust-bin.stable."1.81.0".default
        toolchain = pkgs.rust-bin.stable.latest.default;

        naerskLib = naersk.lib.${system}.override {
          cargo = toolchain.cargo;
          rustc = toolchain.rustc;
        };

        nativeBuildInputs = [pkgs.pkg-config];
        buildInputs = [
          # Add system libraries here if your crates require them, e.g.:
          # pkgs.openssl pkgs.zlib pkgs.xorg.libX11 pkgs.wayland pkgs.libxkbcommon
        ];
      in rec {
        packages.default = naerskLib.buildPackage {
          pname = "doxx";
          src = ./.;

          inherit nativeBuildInputs buildInputs;

          # naersk already builds with --release
          doCheck = false;

          # Optional: smaller binaries; uncomment if desired
          # RUSTFLAGS = "-C strip=symbols";
          # CARGO_PROFILE_RELEASE_LTO = "thin";
          # CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";

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
            toolchain.cargo
            toolchain.rustc
            toolchain.clippy
            toolchain.rustfmt
          ];
          buildInputs = buildInputs;

          shellHook = ''
            echo "→ devShell ready. Try: cargo build --release"
          '';
        };
      }
    );
}
