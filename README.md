# Bootstrap a Linux build VM on macOS

This repository provides a way to bootstrap a Linux builder for Nix on macOS
without relying on an existing Linux builder.

## Instructions

Before performing any of these commands, read the following two security
disclaimers:

* [Security - Cache](#security---cache)
* [Security - Keys](#security---keys)

If you haven't already, add this to `/etc/nix/nix.conf`:

```
extra-experimental-features = nix-command flakes
```

… and then restart your Nix daemon:

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
+ sudo install -g nixbld -m 400 /nix/store/wh01fnnsq7n7hykgc6hlb14a7682pz16-nixbld_ed25519 /etc/nix/nixbld_ed25519
Password:
```

… so that it can install a private key used to `ssh` into the build server.
After that the script will launch the virtual machine:

```
<<< Welcome to NixOS 22.11.20220901.1bd8d11 (aarch64) - ttyAMA0 >>>

Run 'nixos-help' for the NixOS manual.

nixos login:
```

… and your remote builder is good to go!

To use the builder, add the following options to your `nix.conf` file:

```
builders = ssh-ng://builder@localhost aarch64-linux /etc/nix/nixbld_ed25519 - - - - c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo='

# Not strictly necessary, but this will reduce your disk utilization
builders-use-substitutes = true
```

… and then restart your Nix daemon:

```ShellSession
$ sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

… and your done!  Enjoy 😊

## Running an `x86_64-linux` builder from an `aarch64-darwin` system

By default, `nix run` will spin up a Linux builder whose architecture matches
your configured `system`.  In other words:

- if your `system` is `aarch64-darwin` (i.e. Apple silicon), `nix run` will
  create an `aarch64-linux` builder

- if your `system` is `x86_64-darwin`, `nix run` will create an `x86_64-linux`
  builder

However, you might be interested in a third scenario: your `system` is
`aarch64-darwin`, but you want to run an `x86_64-linux` builder.  If that's
the case, then:

- Follow these instructions to enable `x86_64-darwin` builds on your machine:

  [Building x86-64 Packages With Nix on Apple Silicon](https://evanrelf.com/building-x86-64-packages-with-nix-on-apple-silicon)

- Run the following command to create an `x86_64-linux` builder:

  ```ShellSession
  $ nix run --system x86_64-darwin
  ```

Note: there is no way for an `x86_64-darwin` system (i.e. not Apple silicon),
to run an `aarch64-linux` builder, as far as I know.

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

## Security - Keys

In order for this to work the builder has to hard-code the SSH key pair used to
log in (otherwise nobody can prebuild the system for you).  This server runs on
port 22 of your laptop, meaning that if port 22 on your machine is reachable
(i.e. your firewall allows incoming connections port 22), then a malicious
user can log into your builder.

## Acknowledgments

The work in this repository is based in part on prior work from:

- [NixOS/nixpkgs#108984](https://github.com/NixOS/nixpkgs/issues/108984).
- [YorikSar/nixos-vm-on-macos](https://github.com/YorikSar/nixos-vm-on-macos)
