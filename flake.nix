{
  description = "doxx: Terminal .docx viewer (naersk build)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nmattia/naersk";
    # New: modern Rust toolchains
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

        # Latest stable Rust/Cargo from rust-overlay (new enough for Cargo.lock v4)
        toolchain = pkgs.rust-bin.stable.latest;

        # Tell naersk to use that toolchain
        naerskLib = naersk.lib.${system}.override {
          cargo = toolchain.cargo;
          rustc = toolchain.rustc;
        };

        nativeBuildInputs = [pkgs.pkg-config];
        buildInputs = [
          # Add system libs if your crates need them, e.g.:
          # pkgs.openssl pkgs.zlib pkgs.libxkbcommon pkgs.wayland pkgs.xorg.libX11
        ];
      in rec {
        packages.default = naerskLib.buildPackage {
          pname = "doxx";
          src = ./.;

          inherit nativeBuildInputs buildInputs;

          # naersk passes --release itself; do not add it again.
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
            toolchain.cargo
            toolchain.rustc
            toolchain.clippy
            toolchain.rustfmt
          ];
          buildInputs = buildInputs;
          shellHook = ''echo "→ devShell ready. try: cargo build --release" '';
        };
      }
    );
}
