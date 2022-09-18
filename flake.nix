{ inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-darwin" ] (system: rec {
      defaultPackage = packages.default;

      packages = {
        default =
          nixosConfigurations.default.config.system.build.vm;

        builder =
          nixosConfigurations.builder.config.system.build.vm;

        app =
          let
            pkgs = nixpkgs.legacyPackages."${system}";

            privateKey = "/etc/nix/nixbld_ed25519";

          in
            pkgs.writeShellScript "create-builder.sh" ''
              set -x
              sudo install -g nixbld -m 400 ${./keys/nixbld_ed25519} ${privateKey}
              set +x

              ${packages.builder}/bin/run-nixos-vm
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
          nix.settings.trusted-users = [ "root" "builder" ];

          services.openssh.enable = true;

          systemd.services.override-host-key = {
            wantedBy = [ "multi-user.target" ];

            after = [ "sshd.service" ];

            serviceConfig.RemainAfterExit = true;

            script =
              let
                privateKey = "/etc/ssh/ssh_host_ed25519_key";

                publicKey = "${privateKey}.pub";

              in
                ''
                until [ -e ${privateKey} -a -e ${publicKey} ]; do
                  sleep 1
                done

                cp ${./keys/ssh_host_ed25519_key} /etc/ssh/ssh_host_ed25519_key

                cp ${./keys/ssh_host_ed25519_key.pub} /etc/ssh/ssh_host_ed25519_key.pub
                systemctl restart sshd.service
                '';
          };

          system.stateVersion = "22.05";

          users.users.builder = {
            isNormalUser = true;

            openssh.authorizedKeys.keyFiles = [ ./keys/nixbld_ed25519.pub ];
          };

          virtualisation = {
            diskSize = 20480;

            forwardPorts = [
              { from = "host"; guest.port = 22; host.port = 22; }
            ];

            # Disable graphics for the builder since users will likely want to
            # run it non-interactively in the background.
            graphics = false;

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
