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
          success() {
            printf "[\033[32m$1\033[0m]\n\n"
          }
          action() {
            printf "[\033[34m$1\033[0m]\n"
          }

          # set dir ownership
          chmod -R a+rw "$REPO_ROOT" || \
              err_out "failed to set dir permissions\n"
          # create go dir
          mkdir -p "$REPO_ROOT.go" || \
              err_out "failed to create go dir\n"
 
          success "entered nix shell"

          err_log() {
            printf "$@" 1>&2
          }
          
          # build cmd
          build_tmpNote() (
            # strict err exiting
            set -eou pipefail

            # clear go cache
            action "clearing go cache..."
            go clean -modcache

            # clear Zig cache
            action "clearing repo's Zig cache"
            rm -r "$REPO_ROOT/.zig-cache" 2>/dev/null \
                || printf "\tcouldn't clear cache (likely already cleared)\n"

            # save the current directory
            declare -r saved_dir="$PWD"

            # move to repo root
            cd "$REPO_ROOT"

            # tidy go modules
            action "tidying go modules..."
            for p in $(fd 'go.mod|go.sum' -x echo {//}); do
              printf '\t"\033[36m%s\033[0m"\n' "$p"
              cd "$p"
              go mod tidy
              cd "$REPO_ROOT"
            done


            # golang c header export stuff
            action "building headers..."
            # combine into one file
            bun run scripts/combine_go_headers.ts \
              || err_out "failed to combine go headers source"
            cd include
            go mod init tmpNote_combined_headers 2>/dev/null || true
            go mod tidy
            go build -buildmode=c-archive -o combined.a combined.go \
                && success "headers built." \
                || err_out "failed to build headers."
            cd "$REPO_ROOT" # go back to repo root 

            # web ui
            action "building web-ui..."
            bun run scripts/amalgamate_web.ts \
                && success "web-ui built" \
                || err_out "failed to build web-ui\n"

            # zig server
            action "building server..."
            [ "$#" -gt 0 ] && cd "$saved_dir"
            zig build $@ \
                && success "server built" \
                || err_out "failed to build server"

            # return to user's dir
            cd "$saved_dir"
          )
        '';
      };
    };
}
