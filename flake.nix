{
  description = "Milka - a command-line tool for managing multiple git repositories";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    toml-cr = {
      url = "github:crystal-community/toml.cr/v0.8.1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      toml-cr,
    }@inputs:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = lib.genAttrs systems;

      rclString = builtins.toJSON;

      repositoryToRcl = repo: ''
        do
          dir = ${rclString repo.dir}
          remote = ${rclString repo.remote}
          branch = ${rclString (repo.branch or "main")}
        ${lib.optionalString (repo ? commit && repo.commit != null) "  commit = ${rclString repo.commit}\n"}${lib.optionalString (repo ? source && repo.source != null) "  source = ${rclString repo.source}\n"}end'';

      mkRepositoriesRcl = repositories: ''
        do [
        ${lib.concatStringsSep ",\n" (map repositoryToRcl repositories)}
        ]
      '';

      mkRepositoriesPackage =
        {
          pkgs,
          name ? "milka-repositories",
          repositories,
        }:
        pkgs.writeTextFile {
          inherit name;
          destination = "/share/milka/reps.rcl";
          text = mkRepositoriesRcl repositories;
        };

      mkCloneRepositoriesApp =
        {
          pkgs,
          milkaPackage,
          repositoriesPackage,
          name ? "milka-clone-repositories",
        }:
        let
          cloneRepositories = pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
              milkaPackage
            ];
            text = ''
              config="$(mktemp)"
              trap 'rm -f "$config"' EXIT
              cp "${repositoriesPackage}/share/milka/reps.rcl" "$config"
              exec milka --config "$config" clone "$@"
            '';
          };
        in
        {
          type = "app";
          program = "${cloneRepositories}/bin/${name}";
        };

      devenvModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.milka;
          repositoriesPackage = mkRepositoriesPackage {
            inherit pkgs;
            repositories = cfg.repositories;
            name = "milka-devenv-repositories";
          };
        in
        {
          options.milka = {
            repositories = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    dir = lib.mkOption { type = lib.types.str; };
                    remote = lib.mkOption { type = lib.types.str; };
                    branch = lib.mkOption {
                      type = lib.types.str;
                      default = "main";
                    };
                    commit = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    source = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                  };
                }
              );
              default = [ ];
              description = "Repositories cloned by Milka when entering devenv.";
            };

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.milka;
              description = "Milka package used for repository cloning.";
            };

            autoClone = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Clone declared repositories when entering devenv.";
            };
          };

          config = {
            packages = [
              cfg.package
              pkgs.git
            ];

            enterShell = lib.mkIf (cfg.repositories != [ ]) ''
              if [ "${if cfg.autoClone then "1" else "0"}" != "1" ]; then
                echo "Milka repository auto-clone disabled by milka.autoClone = false"
              elif [ "''${MILKA_DEVENV_SKIP_CLONE:-0}" = "1" ]; then
                echo "Skipping Milka repository clone because MILKA_DEVENV_SKIP_CLONE=1"
              else
                echo "Cloning repositories declared in milka.repositories. Set MILKA_DEVENV_SKIP_CLONE=1 to skip."
                config="$(mktemp)"
                cp "${repositoriesPackage}/share/milka/reps.rcl" "$config"
                ${cfg.package}/bin/milka --config "$config" clone || \
                  echo "Repository clone failed; continuing devenv shell startup."
                rm -f "$config"
              fi
            '';
          };
        };
    in
    {
      lib = {
        inherit
          devenvModule
          mkCloneRepositoriesApp
          mkRepositoriesPackage
          mkRepositoriesRcl
          repositoryToRcl
          ;
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          source = lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              let
                base = baseNameOf path;
                rel = lib.removePrefix ((toString ./.) + "/") (toString path);
              in
              !(builtins.elem base [
                ".agents"
                ".codex"
                ".git"
                ".crystal"
                "bin"
                "lib"
                "result"
              ])
              && !(lib.hasPrefix ".crystal/" rel);
          };
        in
        rec {
          default = milka;

          milka = pkgs.stdenv.mkDerivation rec {
            pname = "milka";
            version = "2025.11.8";

            src = source;

            nativeBuildInputs = [
              pkgs.crystal
              pkgs.git
            ];

            postPatch = ''
              mkdir -p lib
              ln -s ${toml-cr} lib/toml
            '';

            buildPhase = ''
              runHook preBuild

              mkdir -p bin
              crystal build src/main.cr -o bin/milka --release --no-debug
              crystal build src/main.cr -o bin/milka-github --release --no-debug -Dgithub_plugin

              runHook postBuild
            '';

            doCheck = true;
            checkPhase = ''
              runHook preCheck

              crystal spec
              crystal spec -Dgithub_plugin

              runHook postCheck
            '';

            installPhase = ''
              runHook preInstall

              install -Dm755 bin/milka "$out/bin/milka"
              install -Dm755 bin/milka-github "$out/bin/milka-github"

              runHook postInstall
            '';

            meta = {
              description = "Command-line tool for managing multiple git repositories";
              homepage = "https://github.com/kogeletey/milka";
              license = lib.licenses.isc;
              mainProgram = "milka";
              platforms = lib.platforms.unix;
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.milka}/bin/milka";
        };

        milka-github = {
          type = "app";
          program = "${self.packages.${system}.milka}/bin/milka-github";
        };
      });

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) milka;
      });

      formatter = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixfmt-rfc-style);

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;

            modules = [
              ({ pkgs, ... }: {
                packages = [
                  pkgs.crystal
                  pkgs.git
                  pkgs.nixfmt-rfc-style
                  pkgs.shards
                ];

                enterShell = ''
                  echo "Milka devenv: crystal, shards, git"
                '';
              })
            ];
          };
        });
    };
}
