{
  description = "A test flake for raspberry pi";

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
  };

  outputs =
    inputs@{
      nixpkgs,
      disko,
      nixos-raspberrypi,
      ...
    }:
    {
      nixosConfigurations.rpi = nixos-raspberrypi.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          inherit inputs;
          inherit (inputs) nixos-raspberrypi;
        };
        modules = [
          disko.nixosModules.disko
          {
            disko.devices.disk.rpi = {
              type = "disk";
              device = "/dev/mmcblk0";
              content = {
                type = "gpt";
                partitions = {
                  FIRMWARE = {
                    label = "FIRMWARE";
                    priority = 1;
                    type = "0700"; # Microsoft basic data
                    attributes = [
                      0 # Required Partition
                    ];
                    size = "1024M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot/firmware";
                      mountOptions = [
                        "noatime"
                        "noauto"
                        "x-systemd.automount"
                        "x-systemd.idle-timeout=1min"
                      ];
                    };
                  };

                  ESP = {
                    label = "ESP";
                    type = "EF00"; # EFI System Partition (ESP)
                    attributes = [
                      2 # Legacy BIOS Bootable, for U-Boot to find extlinux config
                    ];
                    size = "1024M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                      mountOptions = [
                        "noatime"
                        "noauto"
                        "x-systemd.automount"
                        "x-systemd.idle-timeout=1min"
                        "umask=0077"
                      ];
                    };
                  };

                  root = {
                    type = "8305"; # Linux ARM64 root (/)
                    size = "100%";
                    content = {
                      type = "btrfs";
                      extraArgs = [ "-f" ];
                      subvolumes = {
                        "@root" = {
                          mountpoint = "/";
                        };
                        "@swap" = {
                          mountpoint = "/.swapvol";
                          swap.swapfile = {
                            size = "2048M";
                            path = "swapfile";
                          };
                        };
                      };
                    };
                  };
                };
              };
            };
          }

          nixos-raspberrypi.nixosModules.raspberry-pi-4.base
          nixos-raspberrypi.nixosModules.raspberry-pi-4.display-vc4

          {
            boot = {
              initrd = {
                availableKernelModules = [ ];
                kernelModules = [ ];
              };
              kernelModules = [ "bcm2835-v4l2" ];
              extraModulePackages = [ ];
            };

            nixpkgs.hostPlatform = "aarch64-linux";
          }

          {
            services.udev.extraRules = ''
              # Ignore partitions with "Required Partition" GPT partition attribute
              # On our RPis this is firmware (/boot/firmware) partition
              ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
                ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
                ENV{UDISKS_IGNORE}="1"
            '';
          }

          (
            { pkgs, lib, ... }:
            let
              kernelBundle = pkgs.linuxAndFirmware.v6_6_31;
            in
            {
              boot = {
                tmp.useTmpfs = true;
                loader.raspberry-pi.firmwarePackage = kernelBundle.raspberrypifw;
                kernelPackages = kernelBundle.linuxPackages_rpi4;
              };

              nixpkgs.overlays = lib.mkAfter [
                (self: super: {
                  # This is used in (modulesPath + "/hardware/all-firmware.nix") when at least
                  # enableRedistributableFirmware is enabled
                  # I know no easier way to override this package
                  inherit (kernelBundle) raspberrypiWirelessFirmware;
                  # Some derivations want to use it as an input,
                  # e.g. raspberrypi-dtbs, omxplayer, sd-image-* modules
                  inherit (kernelBundle) raspberrypifw;
                })
              ];
            }
          )

          (
            { pkgs, ... }:
            {
              environment.systemPackages = [
                pkgs.btrfs-progs
                pkgs.git
                pkgs.fish
                pkgs.tmux
                pkgs.libraspberrypi
                pkgs.raspberrypi-eeprom
                pkgs.ffmpeg
              ];
            }
          )

          {
            system.stateVersion = "25.11";
            i18n.defaultLocale = "en_US.UTF-8";
            networking.hostName = "rpi";
            # time.timeZone = "Asia/Shanghai";

            users.mutableUsers = false;
            users.users.root.password = "123456";
            users.users.rpi = {
              isNormalUser = true;
              password = "123456";
            };

            nix = {
              channel.enable = false;
              settings = {
                # do we want pipe-operators
                experimental-features = [
                  "nix-command"
                  "flakes"
                ];
                trusted-users = [ "@wheel" ];
              };
            };

            services.openssh = {
              enable = true;
              openFirewall = true;
              allowSFTP = true;
              settings = {
                PasswordAuthentication = true;
                PermitRootLogin = "yes";
              };
            };
          }
        ];
      };
    };
}
