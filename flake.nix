{
  description = "My blog";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };
  nixConfig.sandbox = "relaxed";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        myLibDeps = [
          pkgs.zlib # External C compression library needed by some Haskell packages
        ];
        myLocalDevTools = with pkgs; [
          ghc # GHC compiler in the version above; verify with `ghc --version`
          pkg-config
          zlib
          haskellPackages.hakyll
          stack-wrapped
        ];
        stack-wrapped = pkgs.symlinkJoin {
          name = "stack"; # will be available as the usual `stack` in terminal
          paths = [ pkgs.stack ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/stack \
              --add-flags "\
                --no-nix \
                --system-ghc \
                --no-install-ghc \
              "
          '';
        };
        myApp = pkgs.haskell.lib.buildStackProject {
          name = "myStack";
          src = ./.;
          ghc = pkgs.ghc;
          buildInputs = myLibDeps;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = myLocalDevTools;
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath myLibDeps;
        };
        packages.default = myApp;
      });
}

