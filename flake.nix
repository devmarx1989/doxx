{
  description = "doxx: Terminal .docx viewer (naersk + modern Rust)";

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

        # Modern toolchain that includes std for host target.
        # To pin instead of tracking latest: pkgs.rust-bin.stable."1.81.0".default
        toolchain = pkgs.rust-bin.stable.latest.default;

        # Hand the toolchain to naersk (single derivation provides cargo+rustc)
        naerskLib = naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        };

        nativeBuildInputs = [pkgs.pkg-config];
        buildInputs = [
          # Add system libs here if needed by your crates, e.g.:
          # pkgs.openssl pkgs.zlib pkgs.xorg.libX11 pkgs.wayland pkgs.libxkbcommon
        ];
      in rec {
        packages.default = naerskLib.buildPackage {
          pname = "doxx";
          src = ./.;

          inherit nativeBuildInputs buildInputs;

          # naersk already builds release by default
          doCheck = false;

          # (Optional) smaller release binaries — uncomment if you like
          # RUSTFLAGS = "-C strip=symbols";
          # CARGO_PROFILE_RELEASE_LTO = "thin";
          # CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";

          meta = with pkgs.lib; {
            description = "Beautiful .docx viewing in your terminal";
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
            toolchain # provides cargo, rustc, clippy, rustfmt
          ];
          buildInputs = buildInputs;

          shellHook = ''
            echo "→ devShell ready. Try: cargo build --release"
          '';
        };

        # ── Overlay so others can consume this as pkgs.doxx ─────────────────────
        overlays.default = final: prev: {
          doxx = self.packages.${final.system}.default;
        };
      }
    );
}
