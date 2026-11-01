{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.iamb;
in
{
  options.${namespace}.apps.iamb = {
    enable = lib.mkEnableOption "iamb";
  };

  # Terminal Matrix client, for the Hermes DM on serx's homeserver (tailnet-only). No
  # password_file: the first start prompts for the password, then iamb keeps its own session.
  # Verify that session from another device, or the E2EE DM stays unreadable.
  config = lib.mkIf cfg.enable {
    programs.iamb = {
      enable = true;
      settings = {
        default_profile = "serx";
        # No url: iamb finds the homeserver via its /.well-known/matrix/client.
        profiles.serx.user_id = "@lytharn:matrix.gate-catla.ts.net";
        settings = {
          # Desktop notifications for new messages (Noctalia shows them).
          notifications.enabled = true;
          image_preview = { };
        };
      };
    };
  };
}
