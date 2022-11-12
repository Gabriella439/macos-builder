{ inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-darwin" ] (system:
      let
        keysDirectory = "/var/keys";

        user = "builder";

        keyType = "ed25519";

      in
        rec {
          defaultPackage = packages.default;

          packages = {
            default =
              nixosConfigurations.default.config.system.build.vm;

            builder =
              nixosConfigurations.builder.config.system.build.vm;

            app =
              let
                pkgs = nixpkgs.legacyPackages."${system}";

                privateKey = "/etc/nix/${user}_${keyType}";

                publicKey = "${privateKey}.pub";

                # This installCredentials script is written so that it's as easy
                # as possible for a user to audit before confirming the `sudo`
                installCredentials = pkgs.writeShellScript "install-credentials.sh" ''
                  KEYS="''${1}"
                  INSTALL=${pkgs.coreutils}/bin/install
                  "''${INSTALL}" -g nixbld -m 600 "''${KEYS}/${user}_${keyType}" ${privateKey}
                  "''${INSTALL}" -g nixbld -m 644 "''${KEYS}/${user}_${keyType}.pub" ${publicKey}
                '';

              in
                pkgs.writeShellScript "create-builder.sh" ''
                  KEYS="''${KEYS:-./keys}"
                  ${pkgs.coreutils}/bin/mkdir --parent "''${KEYS}"
                  PRIVATE_KEY="''${KEYS}/${user}_${keyType}"
                  PUBLIC_KEY="''${PRIVATE_KEY}.pub"
                  if [ ! -e "''${PRIVATE_KEY}" ] || [ ! -e "''${PUBLIC_KEY}" ; then
                      ${pkgs.coreutils}/bin/rm --force -- "''${PRIVATE_KEY}" "''${PUBLIC_KEY}"
                      ${pkgs.openssh}/bin/ssh-keygen -q -f "''${PRIVATE_KEY}" -t ${keyType} -N "" -C 'builder@localhost'
                  fi
                  if ! ${pkgs.diffutils}/bin/cmp "''${PUBLIC_KEY}" ${publicKey}; then
                    (set -x; sudo --reset-timestamp ${installCredentials} "''${KEYS}")
                  fi
                  KEYS="$(nix-store --add "$KEYS")" ${packages.builder}/bin/run-nixos-vm
                '';
          };

          defaultApp = apps.default;

          apps.default = {
            type = "app";

            program = "${packages.app}";
          };

          nixosConfigurations =
            let
              toGuest = builtins.replaceStrings [ "darwin" ] [ "linux" ];

            in
              { default = nixpkgs.lib.nixosSystem {
                  system = toGuest system;

                  modules = [ nixosModules.default ];
                };

                builder = nixpkgs.lib.nixosSystem {
                  system = toGuest system;

                  modules = [ nixosModules.builder ];
                };
              };

          nixosModule = nixosModules.default;

          nixosModules = rec {
            vm = { modulesPath, ... }: {
              imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

              # DNS fails for QEMU user networking (SLiRP) on macOS.  See:
              #
              # https://github.com/utmapp/UTM/issues/2353
              #
              # This works around that by using a public DNS server other than the
              # DNS server that QEMU provides (normally 10.0.2.3)
              networking.nameservers = [ "8.8.8.8" ];
            };

            build = {
              environment.etc = {
                "ssh/ssh_host_ed25519_key" = {
                  mode = "0600";

                  source = "${keysDirectory}/ssh_host_ed25519_key";
                };

                "ssh/ssh_host_ed25519_key.pub" = {
                  mode = "0644";

                  source = "${keysDirectory}/ssh_host_ed25519_key.pub";
                };
              };

              nix.settings = {
                auto-optimise-store = true;

                min-free = 1024 * 1024 * 1024;

                max-free = 3 * 1024 * 1024 * 1024;

                trusted-users = [ "root" user ];
              };

              services.openssh = {
                enable = true;

                authorizedKeysFiles = [ "${keysDirectory}/%u_${keyType}.pub" ];
              };

              system.stateVersion = "22.05";

              users.users."${user}"= {
                isNormalUser = true;
              };

              virtualisation = {
                diskSize = 20 * 1024;

                forwardPorts = [
                  { from = "host"; guest.port = 22; host.port = 22; }
                ];

                # Disable graphics for the builder since users will likely want to
                # run it non-interactively in the background.
                graphics = false;

                sharedDirectories.keys = {
                  source = "\"$KEYS\"";
                  target = keysDirectory;
                };

                # If we don't enable this option then the host will fail to delegate
                # builds to the guest, because:
                #
                # - The host will lock the path to build
                # - The host will delegate the build to the guest
                # - The guest will attempt to lock the same path and fail because
                #   the lockfile on the host is visible on the guest
                #
                # Snapshotting the host's /nix/store as an image isolates the guest
                # VM's /nix/store from the host's /nix/store, preventing this
                # problem.
                useNixStoreImage = true;

                # Obviously the /nix/store needs to be writable on the guest in
                # order for it to perform builds.
                writableStore = true;

                # This ensures that anything built on the guest isn't lost when the
                # guest is restarted.
                writableStoreUseTmpfs = false;
              };
            };

            default = {
              imports = [ vm ];

              virtualisation.host.pkgs = nixpkgs.legacyPackages."${system}";
            };

            builder.imports = [ default build ];
          };
        });

  nixConfig = {
    extra-substituters = [ "https://macos-builder.cachix.org" ];

    extra-trusted-public-keys = [
      "macos-builder.cachix.org-1:HPWcq59/iyqQz6HEtlO/kjD/a7ril0+/XJc+SZ2LgpI="
    ];
  };
}
