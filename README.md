# rpi

A repository demonstrate a nixos-raspberrypi issue working with disko && nixos-anywhere.

To reproduce, enable usb boot for raspberry pi 4, flash an usb installation build from https://github.com/nvmd/nixos-raspberrypi, boot up and run the following command on a NixOS machine with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; `.

```bash
nix run nixpkgs#nixos-anywhere -- --build-on local --no-substitute-on-destination --flake .#rpi <target-rpi-host>
```

When it finished successfully, it will reboot into the installed NixOS system, however, if you plug out the usb stick, and reboot, it will stuck at the rainbow screen.
