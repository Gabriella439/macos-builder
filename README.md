# Bootstrap a Linux build VM on macOS

**NOTE:** This has now been
[upstreamed into Nixpkgs](https://nixos.org/manual/nixpkgs/unstable/#sec-darwin-builder)
but I keep this repository around for backwards compatibility and historical reference.

This repository provides a way to bootstrap a NixOS Linux build VM running on
macOS without relying on an existing NixOS builder.  You can then in turn use
that NixOS build VM to to build and run other NixOS VMs on macOS.

## Requirements

This requires macOS version 12.4 or later and Nix version 2.4 or later.

This also requires that port 22 on your machine is free (since Nix does not
permit specifying a non-default SSH port for builders).

You will also need to be a trusted user for your Nix installation.  In other
words, your `/etc/nix/nix.conf` should have something like:

```
extra-trusted-users = <your username goes here>
```

## Instructions

Before performing any of these commands, read the following security disclaimer:

* [Security - Cache](#security---cache)

If you haven't already, add this to `/etc/nix/nix.conf`:

```
extra-experimental-features = nix-command flakes
```

… and then restart your Nix daemon to apply the change:

```ShellSession
$ sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

Then launch a macOS builder by running this command:

```ShellSession
$ nix run github:Gabriella439/macos-builder
```

…and if you trust me then confirm when prompted to do so:

```ShellSession
do you want to allow configuration setting 'extra-substituters' to be set to 'https://macos-builder.cachix.org' (y/N)? y
do you want to permanently mark this value as trusted (y/N)? y
do you want to allow configuration setting 'extra-trusted-public-keys' to be set to 'macos-builder.cachix.org-1:HPWcq59/iyqQz6HEtlO/kjD/a7ril0+/XJc+SZ2LgpI=' (y/N)? y
do you want to permanently mark this value as trusted (y/N)? y
```

That will prompt you to enter your `sudo` password:

```
+ sudo --reset-timestamp /nix/store/…-install-credentials.sh ./keys
Password:
```

… so that it can install a private key used to `ssh` into the build server.
After that the script will launch the virtual machine:

```
<<< Welcome to NixOS 22.11.20220901.1bd8d11 (aarch64) - ttyAMA0 >>>

Run 'nixos-help' for the NixOS manual.

nixos login:
```

… and your remote builder is good to go!  When you need to stop the VM, type
<kbd>Ctrl</kbd>-<kbd>a</kbd> + <kbd>c</kbd> to open the `qemu` prompt and then
type `quit` followed by <kbd>Enter</kbd>.

To use the builder, add the following options to your `nix.conf` file:

```
# - Replace ${ARCH} with either aarch64 or x86_64 to match your host machine
# - Replace ${MAX_JOBS} with the maximum number of builds (pick 4 if you're not sure)
builders = ssh-ng://builder@localhost ${ARCH}-linux /etc/nix/builder_ed25519 ${MAX_JOBS} - - - c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo='

# Not strictly necessary, but this will reduce your disk utilization
builders-use-substitutes = true
```

… and then restart your Nix daemon to apply the change:

```ShellSession
$ sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

… and you're done!  Enjoy 😊

## Building downstream VMs

You don't have to stop there!  You can use the Linux builder you just created
to build and run other NixOS VMs on macOS.  Here is an example of a flake that
you can use as a starting template:

```nix
{ inputs.macos-builder.url = "github:Gabriella439/macos-builder";

  outputs = { macos-builder, nixpkgs, ... }: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      modules = [ macos-builder.nixosModules.aarch64-darwin.default ];

      system = "aarch64-linux";
    };
  };
}
```

… and you can run that NixOS VM on macOS using:

```ShellSession
$ nix run .#nixosConfigurations.default.config.system.build.vm
```

## Architecture match

This only supports running a guest system of the same architecture.

In other words:

- an `aarch64-darwin` host can run an `aarch64-linux` guest
- an `x86_64-darwin` host can run an `x86_64-linux` guest

… but:

- an `aarch64-darwin` host cannot run an `x86_64-linux` guest
- an `x86_64-darwin` host cannot run an `aarch64-linux` guest

## Security - Cache

By trusting my cache you are essentially running arbitrary code you downloaded
from me.  If you don't trust me, then don't confirm when prompted to trust my
cache.

In the long run, this will (hopefully) be built and served by `cache.nixos.org`
so that you don't have to trust me.  If you're patient, you can wait until that
happens.

If you're impatient, then you have to trust me or ask someone who you do trust
that has a Linux builder to build and cache this repository for you.

For what it's worth, I did *not* use the shared aarch64.nixos.community
machine for building this.  I provisioned a blank
`NixOS-22.05.342.a634c8f6c1f-aarch64-linux` AMI to build and populate the
cache.

## Acknowledgments

The work in this repository is based in part on prior work from:

- [NixOS/nixpkgs#108984](https://github.com/NixOS/nixpkgs/issues/108984).
- [YorikSar/nixos-vm-on-macos](https://github.com/YorikSar/nixos-vm-on-macos)
