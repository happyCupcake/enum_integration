{
  description = "Python project with cantools dependency";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ht_can_pkg_flake }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (system:
    let
      makePackageSet = pkgs: {
        py_dbc_proto_gen_pkg = pkgs.py_dbc_proto_gen_pkg;
        proto_gen_pkg = pkgs.proto_gen_pkg;
      };

      py_dbc_proto_gen_overlay = final: prev: {
        py_dbc_proto_gen_pkg = final.callPackage ./dbc_proto_gen_script.nix { };
      };
      proto_gen_overlay = final: prev: {
        proto_gen_pkg = final.callPackage ./dbc_proto_bin_gen.nix { };
      };

      nix_protos_overlays = nix-proto.generateOverlays'
        {
          hytech_np = { proto_gen_pkg }:
            nix-proto.mkProtoDerivation {
              name = "hytech_np";
              buildInputs = [ proto_gen_pkg ];
              src = proto_gen_pkg.out + "/proto";
              version = "1.0.0";
            };
          vn_protos_np = { hytech_np }:
            nix-proto.mkProtoDerivation {
              name = "vn_protos_np";
              src = nix-proto.lib.srcFromNamespace {
                root = ./proto;
                namespace = "vectornav_proto";
              };
              version = "1.0.0";
              protoDeps = [ hytech_np ];
            };
        };

      my_overlays = [
        (final: prev: {
          cantools = prev.cantools.overridePythonAttrs (old: rec {
            version = "39.4.5";
            src = pkgs.fetchPypi {
              pname = "cantools";
              inherit version;
            };
          });
        })
      ];

      pkgs_with_overlays = import nixpkgs {
        inherit system;
        overlays = my_overlays;
      };
    
    in {
      # Development Shell
      devShells.default = pkgs_with_overlays.mkShell {
        packages = with pkgs_with_overlays; [
          python311Packages.cantools  # Include cantools
        ];

        shellHook = ''
          echo "Development environment ready with cantools"
        '';
      };

      packages.default = pkgs_with_overlays.python311Packages.buildPythonPackage {
        pname = "my-python-project";
        version = "1.0.0";

        src = ./.;

        propagatedBuildInputs = with pkgs_with_overlays.python311Packages; [
          cantools  # Propagate the cantools dependency
        ];
      };
    });
}