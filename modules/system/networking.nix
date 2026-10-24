# Networking: hostname, NetworkManager, firewall, mDNS, SSH.
{ config, lib, pkgs, ... }:
{
  networking.hostName = "Sakuya";
  networking.networkmanager.enable = true;
  networking.hosts = { "10.1.1.5" = [ "pronas" ]; };

  networking.firewall = {
    enable = true;

    # Open port ranges for KDE Connect network communication
    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }
    ];
    allowedUDPPortRanges = [
      { from = 1714; to = 1764; }
    ];
  };

  # Network discovery for NDI (.local domains via mDNS).
  services.avahi = {
    enable = true;
    nssmdns4 = true; # Allows software to find .local domains
    # (Renamed from the old publish.{enable,addresses,userServices} options.)
    settings.publish = {
      disable-publishing = false;
      publish-addresses = true;
      disable-user-service-publishing = false;
    };
  };

  # OpenSSH daemon
  services.openssh.enable = true;
}
