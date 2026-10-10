{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.git;
  email = "lytharn@users.noreply.github.com";
in
{
  options.${namespace}.apps.git = {
    enable = lib.mkEnableOption "git";

    sshSigning = {
      enable = lib.mkEnableOption "signing every commit and tag with ~/.ssh/id_ed25519";

      allowedSigners = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "ssh-ed25519 AAAA..." ];
        description = ''
          SSH public keys trusted as ${email} when verifying signatures locally
          (`git log --show-signature`, `git verify-commit`).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs = {
          # delta renders everything git shows (diff, log -p, show, blame, add -p): git's own line
          # diff, so whitespace-only changes are visible too, unlike difftastic.
          delta = {
            enable = true;
            enableGitIntegration = true;
            options = {
              side-by-side = true;
              # tokyonight-night like neovim; the theme comes from the bat module via bat's cache.
              syntax-theme = lib.mkIf config.${namespace}.apps.bat.enable "tokyonight_night";
            };
          };
          # Structural diff on demand via `git dt` (below); it can't show whitespace-only changes.
          # No difftastic.git integration: HM forbids it alongside delta's, and dt doesn't need it.
          difftastic.enable = true;
          git = {
            enable = true;
            # tokyonight-night's delta diff colors (added/removed backgrounds, line numbers).
            includes = [
              { path = "${pkgs.vimPlugins.tokyonight-nvim}/extras/delta/tokyonight_night.gitconfig"; }
            ];
            # Sign with SSH keys, not GPG. Inert unless sshSigning (below) sets a key.
            signing.format = "ssh";
            settings = {
              alias = {
                co = "checkout";
                cp = "cherry-pick";
                st = "status";
                sw = "switch";
                rs = "restore";
                # Reset upstream: discards local commits and uncommitted changes.
                ru = "!git fetch && git reset --hard @{upstream}";
                amend = "commit --amend --no-edit";
                # Plain git diff, without delta.
                dp = "-c pager.diff=less diff";
                # Diff with difftastic instead of delta; takes the same arguments as `git diff`.
                dt = "-c diff.external=${lib.getExe config.programs.difftastic.package} diff";
                # Log aliases: l/ll one-line/full; lt follows first parents only (the mainline);
                # ltr is the last 15 mainline commits, oldest first. rl/rll are the reflog equivalents.
                l = "log --graph --pretty=customone";
                lt = "log --graph --pretty=customone --first-parent";
                ltr = "log -15 --reverse --pretty=customone --first-parent";
                ll = "log --graph --pretty=customfull";
                rl = "reflog --pretty=customrefone";
                rll = "reflog --pretty=customreffull";
              };
              # List most recently committed-to branches first.
              branch.sort = "-committerdate";
              diff = {
                # These shape the diffs delta displays, not `git dt`.
                # Cleaner hunks than myers; matches what merge-ort uses internally.
                algorithm = "histogram";
                # Color moved blocks separately, dimming their unchanged interiors so edits stand out;
                # a block still counts as moved if only its indentation changed.
                colorMoved = "dimmed-zebra";
                colorMovedWS = "allow-indentation-change";
              };
              # Offer to run the closest command on a typo (y/N), never automatically.
              help.autocorrect = "prompt";
              init.defaultBranch = "main";
              # Drop origin/* refs whose branch was deleted on the remote.
              fetch.prune = true;
              # Replay local commits on top of the remote instead of merging when they've diverged.
              pull.rebase = true;
              # First push of a new branch creates and tracks it on the remote.
              push.autoSetupRemote = true;
              rebase = {
                # Stash uncommitted changes around a rebase (and so around `git pull`).
                autoStash = true;
                # In `rebase -i`, move fixup!/squash!/amend! commits (`commit --fixup`) under their
                # target.
                autoSquash = true;
              };
              # Replays recorded conflict resolutions; drop a bad one with `git rerere forget <file>`.
              rerere.enabled = true;
              # Sort tags as versions: v1.9 before v1.10.
              tag.sort = "version:refname";
              user.email = email;
              user.name = "lytharn";
              # Conflict markers also show the common ancestor, with lines shared by both sides moved
              # out.
              merge.conflictstyle = "zdiff3";
              pretty = {
                customone = "format:%C(yellow)%h %C(reset)%s %C(blue)%an %C(green)(%cr) %C(auto)%d";
                customfull = "format:Commit: %C(yellow)%H %C(auto)%d%nAuthor: %C(bold blue)'%an' <%ae> %C(bold green)(%ai)%nCommitter: %C(blue)'%cn' <%ce> %C(green)(%ci)%n%B";
                customrefone = "format:%C(yellow)%h %C(magenta)%gd %C(reset)%s %C(green)(%cr) %C(auto)%d";
                customreffull = "format:Selector: %C(magenta)%gD%nCommit: %C(yellow)%H %C(auto)%d%nAuthor: %C(bold blue)'%an' <%ae> %C(bold green)(%ai)%nCommitter: %C(blue)'%cn' <%ce> %C(green)(%ci)%n%B";
              };
            };
          };
        };
      }
      (lib.mkIf cfg.sshSigning.enable {
        programs.git = {
          signing = {
            # The private key, not the .pub, so signing works without an ssh-agent.
            key = "${config.home.homeDirectory}/.ssh/id_ed25519";
            signByDefault = true;
          };
          # Lets `git log --show-signature`/`verify-commit` trust the allowedSigners keys.
          settings.gpg.ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
        };
        xdg.configFile."git/allowed_signers".text = lib.concatMapStrings (
          key: "${email} namespaces=\"git\" ${key}\n"
        ) cfg.sshSigning.allowedSigners;
      })
    ]
  );
}
