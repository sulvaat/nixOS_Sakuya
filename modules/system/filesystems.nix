# Filesystem mounts: NFS share and btrfs data drives.
{ config, lib, pkgs, ... }:
{
  fileSystems."/home/sul/nfs" = {
    device = "pronas:/var/nfs/shared/Nihonhut";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };

  fileSystems."/mnt/game" = {
    device = "/dev/disk/by-uuid/5798a546-97ca-49d9-b9fc-380a7937fd10";
    fsType = "btrfs";
    options = [
      "users"  # Allows any user to mount and unmount
      "nofail" # Prevent system from failing if this drive doesn't mount
      "exec"
    ];
  };

  fileSystems."/mnt/game2" = {
    device = "/dev/disk/by-uuid/7dccbc2e-98ba-4c98-9d72-af7245f40e53";
    fsType = "btrfs";
    options = [
      "users"
      "nofail"
      "exec"
    ];
  };

  fileSystems."/mnt/blk" = {
    device = "/dev/disk/by-uuid/a3080121-41d5-4223-90a7-52c038d73bba";
    fsType = "btrfs";
    options = [
      "users"
      "nofail"
    ];
  };
}
