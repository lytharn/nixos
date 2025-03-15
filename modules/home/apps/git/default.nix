{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.git;
in
{
  options.${namespace}.apps.git = {
    enable = lib.mkEnableOption "git";
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      aliases = {
        co = "checkout";
        cp = "cherry-pick";
        st = "status";
        amend = "commit --amend --no-edit";
        l = "log --graph --pretty=customone";
        lt = "log --graph --pretty=customone --first-parent";
        ltr = "log -15 --reverse --pretty=customone --first-parent";
        ll = "log --graph --pretty=customfull";
        rl = "reflog --pretty=customref";
        rll = "reflog --pretty=customreffull";
      };
      userEmail = "lytharn@users.noreply.github.com";
      userName = "lytharn";
      difftastic.enable = true;
      extraConfig = {
        merge = {
          conflictstyle = "diff3";
        };
        pretty = {
          customone = "format:%C(yellow)%h %C(reset)%s %C(blue)%an %C(green)(%cr) %C(magenta)%d";
          customfull = "format:Commit: %C(yellow)%H %C(magenta)%d%nAuthor: %C(bold blue)'%an' <%ae> %C(bold green)(%ai)%nCommitter: %C(blue)'%cn' <%ce> %C(green)(%ci)%n%B";
          customrefone = "format:%C(yellow)%h %C(magenta)%gd %C(reset)%s %C(green)(%cr) %C(magenta)%d";
          customreffull = "format:Selector: %C(magenta)%gD%nCommit: %C(yellow)%H %C(magenta)%d%nAuthor: %C(bold blue)'%an' <%ae> %C(bold green)(%ai)%nCommitter: %C(blue)'%cn' <%ce> %C(green)(%ci)%n%B";
        };
      };
    };
  };
}
