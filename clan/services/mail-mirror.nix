{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/mail-mirror";
  manifest.description = "Pull-only local mirror of an IMAP mailbox, indexed with notmuch, readable by chosen users";
  manifest.readme = ''
    A `mailsync` system user mirrors the chosen IMAP folders into a local Maildir with mbsync
    (`Sync Pull`, no expunge/remove: the server is never modified) and indexes it with notmuch.
    The IMAP login (username + password) is a clan var prompt readable only by `mailsync`; the
    `readers` (e.g. the Hermes agent) are put in its group and get read-only access to the
    Maildir and index — they never see the credentials and can't change the mirror. Not backed
    up: the server holds the mail. serx-only.
  '';

  roles.default = {
    description = "Machine holding the mail mirror";
    interface =
      { lib, ... }:
      {
        options = {
          host = lib.mkOption {
            type = lib.types.str;
            example = "imap.example.com";
            description = "IMAP server (IMAPS, port 993).";
          };
          folders = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "INBOX" ];
            description = "IMAP folders to mirror (mbsync `Patterns`).";
          };
          readers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Users given read-only access to the mirror and its notmuch index.";
          };
          interval = lib.mkOption {
            type = lib.types.str;
            default = "5min";
            description = "How often to sync (systemd time span).";
          };
        };
      };
    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            stateDir = "/var/lib/mail-mirror";
            maildir = "${stateDir}/Maildir";
            secrets = config.clan.core.vars.generators.mail-mirror.files;

            mbsyncConfig = pkgs.writeText "mbsyncrc" ''
              IMAPAccount mail
              Host ${settings.host}
              Port 993
              TLSType IMAPS
              CertificateFile /etc/ssl/certs/ca-certificates.crt
              UserCmd "cat ${secrets.user.path}"
              PassCmd "cat ${secrets.password.path}"

              IMAPStore mail-remote
              Account mail

              MaildirStore mail-local
              Path ${maildir}/
              Inbox ${maildir}/INBOX
              SubFolders Verbatim

              # Pull-only: copy new mail down; never create, flag, expunge or remove anything
              # on the server.
              Channel mail
              Far :mail-remote:
              Near :mail-local:
              Patterns ${lib.concatMapStringsSep " " (f: ''"${f}"'') settings.folders}
              Create Near
              Remove None
              Expunge None
              Sync Pull
              SyncState *
              CopyArrivalDate yes
            '';
            # Read by the sync (as mailsync) and by readers (via /etc), so it's in /etc.
            notmuchConfig = ''
              [database]
              path=${maildir}

              [new]
              tags=unread;inbox;
              ignore=.mbsyncstate;.mbsyncstate.journal;.mbsyncstate.new;.mbsyncstate.lock;.uidvalidity

              [maildir]
              # A mirror: notmuch must never rename message files to sync flags.
              synchronize_flags=false
            '';
          in
          {
            users = {
              users = {
                mailsync = {
                  isSystemUser = true;
                  group = "mailsync";
                  home = stateDir;
                };
              }
              # Readers get read access through the group (files are made group-readable below).
              // lib.genAttrs settings.readers (_: {
                extraGroups = [ "mailsync" ];
              });
              groups.mailsync = { };
            };

            environment.etc."mail-mirror/notmuch-config".text = notmuchConfig;

            systemd.services.mail-mirror = {
              description = "Mirror IMAP mail into the local Maildir and index it";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              path = [
                pkgs.isync
                pkgs.notmuch
                pkgs.coreutils
              ];
              environment.NOTMUCH_CONFIG = "/etc/mail-mirror/notmuch-config";
              serviceConfig = {
                Type = "oneshot";
                User = "mailsync";
                Group = "mailsync";
                StateDirectory = "mail-mirror";
                StateDirectoryMode = "0750";
                UMask = "0027";
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                PrivateDevices = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectKernelLogs = true;
                ProtectControlGroups = true;
                RestrictSUIDSGID = true;
                LockPersonality = true;
                CapabilityBoundingSet = "";
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_UNIX"
                ];
              };
              script = ''
                mkdir -p ${maildir}
                mbsync --config ${mbsyncConfig} --all --quiet
                notmuch new --quiet
                # mbsync writes messages 0600; make the mirror group-readable for the readers.
                chmod -R g+rX,g-w ${stateDir}
              '';
            };
            systemd.timers.mail-mirror = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "1min";
                OnUnitActiveSec = settings.interval;
              };
            };

            clan.core.vars.generators.mail-mirror = {
              files.user.owner = "mailsync";
              files.password.owner = "mailsync";
              prompts.user = {
                description = "IMAP username for the mail mirror (usually the full email address)";
                persist = true;
              };
              prompts.password = {
                description = "IMAP password for the mail mirror";
                type = "hidden";
                persist = true;
              };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''
                tr -d "\n" < "$prompts"/user > "$out"/user
                tr -d "\n" < "$prompts"/password > "$out"/password
              '';
            };
          };
      };
  };
}
