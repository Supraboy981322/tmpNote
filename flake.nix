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
        '';
      };
    };
}
