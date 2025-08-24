{
  description = "doxx - Expose the contents of .docx files without leaving your terminal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    naersk.url = "github:nix-community/naersk";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
    naersk,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {inherit system overlays;};

        # Toolchain (stable latest) w/ extras
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = ["rust-src" "clippy" "rustfmt"];
        };

        # Naersk wired to our toolchain
        naerskLib = naersk.lib.${system}.override {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        # Read package info from local Cargo.toml (no duplication)
        cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        pname = cargoToml.package.name or "doxx";
        version = cargoToml.package.version or "0.0.0";
        description =
          if cargoToml.package ? description
          then cargoToml.package.description
          else "Expose the contents of .docx files without leaving your terminal";

        # If you ever prefer building a remote source instead of local checkout:
        # src = pkgs.fetchFromGitHub {
        #   owner = "bgreenwell";
        #   repo  = "doxx";
        #   rev   = "v${version}";
        #   # run: nix-prefetch-github bgreenwell doxx --rev v${version}
        #   sha256 = "sha256-REPLACE_ME";
        # };
        src = ./.; # build local workspace by default
      in rec {
        packages.default = naerskLib.buildPackage {
          inherit pname version src;

          # Keep native/build inputs minimal unless you truly need more
          nativeBuildInputs = [pkgs.pkg-config];

          # Only include what you actually link against at runtime.
          # doxx is terminal-only; X11 is kept for clipboard/terminal libs that may get pulled.
          buildInputs =
            pkgs.lib.optionals pkgs.stdenv.isLinux [pkgs.xorg.libX11]
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.Security
              pkgs.darwin.apple_sdk.frameworks.CoreFoundation
              pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
              pkgs.darwin.apple_sdk.frameworks.AppKit
              pkgs.darwin.apple_sdk.frameworks.Cocoa
            ];

          # If you actually depend on OpenSSL (native-tls), uncomment:
          # OPENSSL_DIR = "${pkgs.openssl.dev}";
          # OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
          # OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";

          meta = with pkgs.lib; {
            description = description;
            homepage = cargoToml.package.homepage or "https://github.com/bgreenwell/doxx";
            license =
              if cargoToml.package ? license
              then licenses.${cargoToml.package.license}
              else licenses.mit;
            platforms = platforms.linux ++ platforms.darwin;
            mainProgram = pname;
          };
        };

        # Nice alias
        packages.${pname} = packages.default;

        # `nix run` convenience
        apps.default = {
          type = "app";
          program = "${packages.default}/bin/${pname}";
        };

        # Dev shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs;
            [
              rustToolchain
              rust-analyzer
              pkg-config
              git
              # helpful cargo tools
              cargo-watch
              cargo-edit
              cargo-audit
              cargo-deny
              cargo-outdated
              cargo-expand
              # debugging
              gdb
              valgrind
              # optional docx tooling for tests
              pandoc
              libreoffice
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux [xorg.libX11]
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              darwin.apple_sdk.frameworks.Security
              darwin.apple_sdk.frameworks.CoreFoundation
              darwin.apple_sdk.frameworks.SystemConfiguration
              darwin.apple_sdk.frameworks.AppKit
              darwin.apple_sdk.frameworks.Cocoa
            ];

          TERM = "xterm-256color";
          shellHook = ''
            echo "❄️ Welcome to the doxx Nix development environment!"
            echo ""
            echo "📋 Dependencies loaded:"
            echo "  - Rust ${rustToolchain.version} with clippy, rustfmt, rust-src"
            echo "  - ratatui for terminal UI"
            echo "  - crossterm for cross-platform terminal"
            echo "  - arboard for clipboard support"
            echo "  - docx-rs for document parsing"
            echo ""
            echo "❄️ Nix commands:"
            echo "  nix build                - Build the project"
            echo "  nix run                  - Run doxx"
            echo "  nix run . -- --help      - Run with help flag"
            echo "  nix develop              - Enter this dev shell"
            echo "  nix flake check          - Run all checks (fmt, clippy, build)"
            echo ""
            echo "📄 Usage examples:"
            echo "  nix run . -- document.docx"
            echo "  nix run . -- document.docx --outline"
            echo "  nix run . -- document.docx --search 'keyword'"
            echo "  nix run . -- document.docx --export csv"
            echo ""
            echo "🔧 Development commands:"
            echo "  cargo build              - Direct build (uses Nix env)"
            echo "  cargo watch -x run       - Live reload during development"
            echo "  cargo clippy             - Run linter"
            echo "  cargo fmt                - Format code"
            echo ""
            echo "💡 Pro tip: 'nix run github:bgreenwell/doxx -- file.docx' to run from anywhere!"
            echo ""
          '';
        };

        # CI-ish checks (use the same src)
        checks = {
          build = packages.default;

          fmt-check = pkgs.runCommand "fmt-check" {buildInputs = [rustToolchain];} ''
            cp -r ${src} src
            chmod -R u+w src
            cd src
            cargo fmt --all -- --check
            touch $out
          '';

          clippy-check = pkgs.runCommand "clippy-check" {buildInputs = [rustToolchain];} ''
            cp -r ${src} src
            chmod -R u+w src
            cd src
            cargo clippy --all-targets --all-features -- -D warnings
            touch $out
          '';
        };
      }
    );
}
