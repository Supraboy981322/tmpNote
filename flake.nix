{
  description = "tmpNote";

  inputs = {
    pkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    zig_overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zig_overlay, ... } @ inputs: 
    let
      system = "x86_64-linux";
      zigVersion = "0.15.2";

      zig = zig_overlay.packages.${system}.${zigVersion};

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ zig_overlay.overlays.default ];
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          zig
          pkgs.go

          # for development scripts
          pkgs.jq
          pkgs.curl
          pkgs.bash
        ];

        shellHook = ''
          printf "entering tmpNote nix shell"

          # build cmd
          build_tmpNote() (
            # strict err exiting
            set -eou pipefail

            # golang c header export stuff
            printf "building headers..."
            for header_src in $(ls include/*.go); do
              # get name without file extension
              declare name="$(printf "$header_src" | sed 's|.go$||')"

              # print current file
              printf "\t%s (output: %s.a and %s.h)\n" \
                    "$header_src" \
                    "$name" \
                    "$name"

              # compile C header file
              go build -buildmode=c-archive -o $name.a $header_src
            done
            printf "headers built.\n"

            # zig server
            printf "building server...\n"
            zig build
            printf "server built\n"
          )
        '';
      };
    };
}
