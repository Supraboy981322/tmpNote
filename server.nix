{ pkgs, zig }:
let
  compression_lib = pkgs.buildGoModule {
    pname = "compression";
    version = "0.0.0";
    src = ./include;
    vendorHash = "sha256-ShSgQW5p9AoMd93Z4UFbD+u5ndZ3O5UBdE2HDvlX168=";
    buildInputs = with pkgs; [
      gcc
      pkg-config
      brotli.dev
    ];
    buildPhase = ''
      go build -buildmode=c-archive -o compress.a compress.go
    '';
    installPhase = ''
      mkdir -p $out/include
      cp compress.a compress.h $out/include
    '';
  };
in
  pkgs.stdenv.mkDerivation {
    pname = "tmpNote";
    version = "0.0.0";
    src = ./.;

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
    nativeBuildInputs = [ zig ] ++ (with pkgs; [
      go
      bun
      coreutils
      pkg-config
      brotli.dev
    ]);
    buildPhase = '' 
      export HOME=$(pwd)
      export GOMODCACHE=$(pwd)/.go/pkg/mod
      export GOPATH=$(pwd)/.go
      export NODE_PATH=$(pwd)/node_modules
      #export CPATH=${compression_lib}/include:$CPATH
      #export CPATH=${compression_lib}/include:$CPATH
      mkdir -p $out
      chmod -R +w .
      cp ${compression_lib}/include/* include
      ls include
      zig build #-Doptimize=ReleaseSafe
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp ./zig-out/bin/tmpNote $out/bin/tmpNote
    '';
  }
