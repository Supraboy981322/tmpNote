{
  description = "tmpNote";

  inputs = {
    # nixpkgs unstable for latest versions
    pkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # import Zig overlay
    zig_overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zig_overlay, ... } @ inputs: 
    let
      # system version (you may need to change this)
      system = "x86_64-linux";

      repo_root = builtins.toString ./.;

      # the server only compiles on one Zig version 
      zigVersion = "0.15.2";

      # selected Zig package
      zig = zig_overlay.packages.${system}.${zigVersion};

      # add the Zig overlay pkgs
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ zig_overlay.overlays.default ];
      };
    in {
      # Nix shell
      devShells.${system}.default = pkgs.mkShell {
        # environment variables
        #REPO_ROOT = repo_root;
        
        # install packages
        packages = (with pkgs; [
          # languages (see end of list for Zig (not in pkgs))
          go

          # dependencies
          brotli.dev

          # for development scripts
          jq
          bun
          curl
          bash
          pkg-config
        ]) ++ [ zig ]; # this language too

        # setup shell
        shellHook = ''
          printf "\n\nsetting up shell...\n"

          # get repo root
          export REPO_ROOT="$(git rev-parse --show-toplevel)"

          # attempt at fixing go failing to build (permissions)
          export GOMODCACHE=$REPO_ROOT/.go/pkg/mod
          export GOPATH=$REPO_ROOT/.go

          # print to stderr then exit
          err_out() {
            printf "$@" 1>&2
            exit 1
          }

          # set dir ownership
          chmod -R a+rw "$REPO_ROOT" || \
              err_out "failed to set dir permissions\n"
          # create go dir
          mkdir -p "$REPO_ROOT.go" || \
              err_out "failed to create go dir\n"
 
          printf "entered nix shell\n"

          # build cmd
          build_tmpNote() (
            # strict err exiting
            set -eou pipefail

            # clear go cache
            printf "clearing go cache...\n"
            go clean -modcache

            # clear Zig cache
            printf "clearing repo's Zig cache\n"
            rm -r "$REPO_ROOT/.zig-cache"

            # save the current directory
            declare -r saved_dir="$PWD"

            # move to repo root
            cd "$REPO_ROOT"

            # tidy go modules
            printf "tidying go modules...\n"
            for p in $(fd 'go.mod|go.sum' -x echo {//}); do
              printf '\t"\033[36m%s\033[0m"\n' "$p"
              cd "$p"
              go mod tidy
              cd "$REPO_ROOT"
            done

            # golang c header export stuff
            printf "building headers...\n"
            cd "include" # move to include dir
            for header_src in $(ls *.go); do
              # get name without file extension
              declare name="$(printf "$header_src" | sed 's|.go$||')"

              # create msg for which file
              declare msg='\t"\033[33m%s\033[0m"'
              msg+=' (output: "\033[34m%s\033[0m"'
              msg+=' and "\033[35m%s\033[0m")\n'

              # log current file
              printf "$msg" "$header_src" "$name.a" "$name.h"

              # compile C header file
              go build -buildmode=c-archive -o $name.a $header_src
            done
            cd "$REPO_ROOT" # go back to repo root 
            printf "headers built.\n"

            # zig server
            printf "building server...\n"
            zig build
            printf "server built\n"

            # return to user's dir
            cd "$saved_dir"
          )
        '';
      };
    };
}
