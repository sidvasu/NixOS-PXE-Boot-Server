# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  
  # Provides dynamic linker that regular Linux binaries use
  programs.nix-ld.enable = true;

  boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "pxeserver";
  networking.domain = "example.com";

  networking.defaultGateway = {
    address = "127.0.0.1"; # Replace with gateway address
    interface = "ens18"; # Replace with interface
  };

  # Pick only one of the below networking options for WiFi or Ethernet (default)
  # networking.wireless = {
  #   enable = true;  # Enables wireless support via wpa_supplicant.
  #   networks."MySSID".psk = "password";
  # };
  networking.useDHCP = false;
  networking.interfaces.ens18.ipv4.addresses = [ {
    address = "127.0.0.1"; # Replace with server internal IP address
    prefixLength = 24;
  } ];
  networking.interfaces.ens18.mtu = 1400;

  networking.nameservers = [ "1.1.1.1" ];

  users.users."anon" = {
    isNormalUser = true;
    home = "/home/anon";
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim
    wget
    adcli
    oddjob
    samba4Full
    sssd
    krb5
    realmd
  ];

  services.openssh = {
    enable = true;

    settings = {
      TrustedUserCAKeys = "/etc/ssh/vault-ca.pub";
      AuthorizedPrincipalsFile = "/etc/ssh/auth_principals/%u";
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      UsePAM = true;
    };
  };

  users.users."root".openssh.authorizedKeys.keyFiles = [
    /etc/nixos/ssh/authorized_keys
  ];

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      port = 0;
      interface = "ens18";
      bind-interfaces = true;

      dhcp-range = "127.0.0.1,proxy" # Replace address with subnet

      enable-tftp = true;
      tftp-root = "/srv/tftp";

      pxe-prompt = ''"PXE boot",3'';
      pxe-service = [
        ''x86PC,"netboot.xyz (BIOS)",netboot.xyz.kpxe''
        ''x86-64_EFI,"netboot.xyz (UEFI)",netboot.xyz.efi''
      ];
    };
  };

  services.vsftpd = {
    enable = true;
    localUsers = true;
    writeEnable = true;
    userlist = [ "anon" ];
    userlistEnable = true;
    chrootlocalUser = true;
    extraConfig = ''
      pasv_enable=Yes
      pasv_min_port=56250
      pasv_max_port=56260
      local_root=/srv/tftp
      allow_writeable_chroot=YES
    '';
  };

  security.krb5 = {
    enable = true;
    settings = {
      libdefaults = {
        udp_preference_limit = 0;
        default_realm = "EXAMPLE.COM";
      };
    };
  };

  services.sssd = {
    enable = true;
    config = ''
      [sssd]
      domains = example.com
      config_file_version = 2
      services = nss, pam

      [domain/example.com]
      override_shell = /run/current-system/sw/bin/bash
      krb5_store_password_if_offline = True
      cache_credentials = True
      krb5_realm = EXAMPLE.COM
      realmd_tags = manages-system joined-with-samba
      id_provider = ad
      fallback_homedir = /home/%u
      ad_domain = example.com
      use_fully_qualified_names = false
      auth_provider = ad
      access_provider = ad
      chpass_provider = ad
      ad_gpo_access_control = permissive
      enumerate = true
      krb5_canonicalize = false
    '';
  };

  security.pam = {
    makeHomeDir.umask = "077";
    services.login.makeHomeDir = true;
    services.sshd.makeHomeDir = true;
    services.sshd.sssdStrictAccess = true;
  };

  services.realmd.enable = true;
  services.qemuGuest.enable = true;
  programs.oddjobd.enable = true;

  services.samba = {
    enable = true;
    nmbd.enable = false;
    winbindd.enable = false;
    package = pkgs.samba4Full;
    settings.global = {
      "security" = "ads";
      "realm" = "EXAMPLE.COM";
      "workgroup" = "EXAMPLE";
      "client use spnego" = "yes";
      "restrict anonymous" = "2";
      "server signing" = "mandatory";
      "client signing" = "mandatory";
      "kerberos method" = "secrets and keytab";
    };
  };

  systemd.tmpfiles.rules = [ "d /srv/tftp 0755 root root -" ];

  networking.firewall.allowedUDPPorts = [67 69 4011];
  networking.firewall.allowedTCPPorts = [21];
  networking.firewall.allowedTCPPortRanges = [
    { from = 56250; to = 56260; }
  ];

  system.stateVersion = "25.05";

}
