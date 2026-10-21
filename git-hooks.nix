# Git hooks for this repo, via git-hooks.nix. Exposed as `checks.<system>.git-hooks` (so
# `nix flake check` runs the file hooks over the whole tree) and installed into .git/hooks by
# the dev shell's shellHook, so they're active wherever direnv / `nix develop` has loaded it.
#   - pre-commit: nixfmt on staged .nix files, the same formatter `nix fmt` uses.
#   - commit-msg: subject <= 72 chars, blank second line, body lines <= 72 chars.
# Bypass a single commit with `git commit --no-verify`.
{ pkgs, git-hooks }:
let
  # Lines without a space (a URL, a long path) can't be wrapped, so they're exempt. Comment
  # lines and anything below the `commit -v` scissors line are stripped by git, so skipped.
  checkCommitMsg = pkgs.writeShellScript "check-commit-msg" ''
    exec ${pkgs.gawk}/bin/awk -v max=72 '
      /^# -+ >8 -+$/ { exit }
      /^#/ { next }
      { n++
        if (n == 1 && length($0) == 0) { print "commit-msg: empty subject line"; bad = 1 }
        if (n == 1 && length($0) > max) {
          printf "commit-msg: subject is %d chars (max %d)\n", length($0), max; bad = 1 }
        if (n == 2 && length($0) > 0) {
          print "commit-msg: second line must be blank"; bad = 1 }
        if (n > 2 && length($0) > max && $0 ~ / /) {
          printf "commit-msg: line %d is %d chars (max %d)\n", n, length($0), max; bad = 1 }
      }
      END { exit bad }
    ' "$1"
  '';
in
git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
  src = ./.;
  hooks = {
    nixfmt.enable = true;
    commit-msg-format = {
      enable = true;
      name = "commit message format";
      entry = "${checkCommitMsg}";
      stages = [ "commit-msg" ];
    };
  };
}
