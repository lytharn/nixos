{
  config,
  options,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.restic-server;
  # privateRepos grants access only under a subdir matching its auth user, so the
  # repo for a client lives at <dataDir>/<client>.
  repo = "${cfg.dataDir}/${cfg.client}";
in
{
  options.${namespace}.services.restic-server = {
    enable = lib.mkEnableOption "restic-server";

    client = lib.mkOption {
      type = lib.types.str;
      example = "serx";
      description = ''
        Name of the client whose repository this server hosts. With privateRepos
        enabled the client may only access the subdirectory matching its basic-auth
        username, so this must equal that username. The repo lives at
        <dataDir>/<client>, and the prune job runs against it.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = options.services.restic.server.dataDir.default;
      example = "/backup";
      description = ''
        Directory the rest-server stores repositories under. Point it at a dedicated
        filesystem/subvolume sized for the backups (e.g. a btrfs subvolume mounted
        compress=no, since restic data is already compressed).
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "TCP port the rest-server listens on (opened on the tailnet only).";
    };

    retention = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--keep-daily=7"
        "--keep-weekly=4"
        "--keep-monthly=6"
      ];
      description = "restic forget flags controlling how many snapshots the prune job keeps.";
    };

    pruneSchedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun 03:00";
      description = "systemd OnCalendar expression for the prune/check job.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Append-only restic REST server. Client pushes its backups here but cannot delete
    # or modify existing snapshots, so a compromised client can't wipe its own history.
    # The restic repo is client-side encrypted, so the data is encrypted at rest on
    # server's disk.
    services.restic.server = {
      enable = true;
      appendOnly = true;
      privateRepos = true;
      dataDir = cfg.dataDir;
      listenAddress = toString cfg.port; # socket-activated; bare port, no interface
      htpasswd-file = config.sops.templates."restic-htpasswd".path;
    };

    # Only the bcrypt hash is secret; the username is cfg.client, so the htpasswd line is
    # assembled by a sops template. Deriving the username from cfg.client keeps it in sync
    # with the repo subdir and privateRepos check (no chance of a mismatched user).
    sops.secrets.restic-htpasswd-hash = { };
    sops.templates."restic-htpasswd" = {
      owner = "restic"; # read by the rest-server's "restic" system user
      content = "${cfg.client}:${config.sops.placeholder.restic-htpasswd-hash}";
    };

    # Only reachable over the tailnet.
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ cfg.port ];

    # Pruning runs here, not on client: append-only blocks client from deleting, so the
    # repo's retention/forget is the trusted job that runs locally against the repo dir
    # (append-only only restricts the HTTP path, not local filesystem access).
    # Run as the "restic" user so repacked pack files keep the ownership the rest-server
    # expects for client's subsequent backups.
    sops.secrets.restic-repo-pass.owner = "restic";

    systemd.services."restic-prune-${cfg.client}" = {
      description = "Prune and verify ${cfg.client}'s restic repository";
      environment.RESTIC_PASSWORD_FILE = config.sops.secrets.restic-repo-pass.path;
      serviceConfig = {
        Type = "oneshot";
        User = "restic";
        Group = "restic";
      };
      script = ''
        # The repo only exists after client has run its first backup (restic init).
        test -e ${repo}/config || exit 0
        ${lib.getExe pkgs.restic} -r ${repo} forget --prune ${lib.concatStringsSep " " cfg.retention}
        # Verify repo structure every run, plus a rolling 5% of pack data to catch
        # at-rest bit-rot (btrfs has no redundancy here, so this is the only such check).
        ${lib.getExe pkgs.restic} -r ${repo} check --read-data-subset=5%
      '';
    };

    systemd.timers."restic-prune-${cfg.client}" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.pruneSchedule;
        Persistent = true;
      };
    };
  };
}
