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
        lib = pkgs.lib;
        L = pkgs.lib.licenses;

        # Toolchain (stable) with extras
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = ["rust-src" "clippy" "rustfmt"];
        };

        # Naersk wired to our toolchain
        naerskLib = naersk.lib.${system}.override {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        # Read package info from local Cargo.toml (avoids duplication)
        cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        pname = cargoToml.package.name or "doxx";
        version = cargoToml.package.version or "0.0.0";
        description =
          if cargoToml.package ? description
          then cargoToml.package.description
          else "Expose the contents of .docx files without leaving your terminal";

        # SPDX → nix license mapper (covers common cases, supports OR/AND)
        # If we cannot map, we return null, and omit meta.license.
        spdxToAttr = s: let
          m = {
            "MIT" = L.mit;
            "Apache-2.0" = L.asl20;
            "BSD-3-Clause" = L.bsd3;
            "BSD-2-Clause" = L.bsd2;
            "MPL-2.0" = L.mpl20;
            "ISC" = L.isc;
            "Unlicense" = L.unlicense;
            "GPL-3.0-only" = L.gpl3Only;
            "GPL-3.0-or-later" = L.gpl3Plus;
            "LGPL-3.0-only" = L.lgpl3Only;
            "LGPL-3.0-or-later" = L.lgpl3Plus;
            "CC0-1.0" = L.cc0;
          };
        in
          if m ? ${s}
          then m.${s}
          else null;

        parseLicenseString = s: let
          # remove simple parentheses
          cleaned = lib.strings.replaceStrings ["(" ")"] ["" ""] s;
          # split on OR/AND (both supported)
          ors = lib.strings.splitString " OR " cleaned;
          parts = lib.concatMap (p: lib.strings.splitString " AND " p) ors;
          mapped = lib.filter (x: x != null) (map spdxToAttr parts);
        in
          if mapped == []
          then null
          else if lib.length mapped == 1
          then builtins.elemAt mapped 0
          else mapped;

        licenseAttr =
          if cargoToml.package ? license
          then parseLicenseString cargoToml.package.license
          else null;

        # Build local checkout by default
        src = ./.;

        doxx = naerskLib.buildPackage {
          inherit pname version src;

          nativeBuildInputs = [pkgs.pkg-config];

          # Keep runtime deps minimal; add/remove as your crate needs.
          buildInputs =
            lib.optionals pkgs.stdenv.isLinux [pkgs.xorg.libX11]
            ++ lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.Security
              pkgs.darwin.apple_sdk.frameworks.CoreFoundation
              pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
              pkgs.darwin.apple_sdk.frameworks.AppKit
              pkgs.darwin.apple_sdk.frameworks.Cocoa
            ];

          # If you actually link native-tls/OpenSSL, uncomment:
          # OPENSSL_DIR = "${pkgs.openssl.dev}";
          # OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
          # OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";

          meta =
            (with lib; {
              inherit description;
              homepage = cargoToml.package.homepage or "https://github.com/bgreenwell/doxx";
              platforms = platforms.linux ++ platforms.darwin;
              mainProgram = pname;
            })
            // lib.optionalAttrs (licenseAttr != null) {license = licenseAttr;};
        };
      in rec {
        packages.default = doxx;
        packages.${pname} = doxx;

        apps.default = {
          type = "app";
          program = "${doxx}/bin/${pname}";
        };

        # Dev shell w/ your detailed welcome banner
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs;
            [
              rustToolchain
              rust-analyzer
              pkg-config
              git
              cargo-watch
              cargo-edit
              cargo-audit
              cargo-deny
              cargo-outdated
              cargo-expand
              gdb
              valgrind
              pandoc
              libreoffice
            ]
            ++ lib.optionals pkgs.stdenv.isLinux [pkgs.xorg.libX11]
            ++ lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.Security
              pkgs.darwin.apple_sdk.frameworks.CoreFoundation
              pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
              pkgs.darwin.apple_sdk.frameworks.AppKit
              pkgs.darwin.apple_sdk.frameworks.Cocoa
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
            echo "🔧 Development commands (if you need them):"
            echo "  cargo build              - Direct build (uses Nix env)"
            echo "  cargo watch -x run       - Live reload during development"
            echo "  cargo clippy             - Run linter"
            echo "  cargo fmt                - Format code"
            echo ""
            echo "💡 Pro tip: 'nix run github:bgreenwell/doxx -- file.docx' to run from anywhere!"
            echo ""
          '';
        };

        # Simple checks using same src
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
