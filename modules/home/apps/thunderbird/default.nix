{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.thunderbird;

  # Thunderbird discovers the individual calendars/address books under this base via CalDAV/
  # CardDAV auto-discovery. If discovery ever fails, point at a specific collection instead, e.g.
  # https://cloud.gate-catla.ts.net/remote.php/dav/calendars/<user>/personal/
  davUrl = "https://cloud.gate-catla.ts.net/remote.php/dav/";

  profile = "lytharn";
in
{
  options.${namespace}.apps.thunderbird = {
    enable = lib.mkEnableOption "Thunderbird mail client";

    nextcloudUser = lib.mkOption {
      type = lib.types.str;
      default = "lytharn";
      description = "Nextcloud username for the CalDAV/CardDAV accounts.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.thunderbird = {
      enable = true;
      profiles.${profile}.isDefault = true;
    };

    # Mail account is intentionally NOT declared here: the address is private (public repo, spam
    # harvesting) and Thunderbird can't consume a clan var for account identity anyway.

    # Calendar (CalDAV, two-way sync with Nextcloud). basePath is required by the HM accounts
    # module even though Thunderbird doesn't use it (it's for local/vdirsyncer-style storage).
    accounts.calendar.basePath = ".calendars";
    accounts.calendar.accounts.nextcloud = {
      primary = true;
      remote = {
        type = "caldav";
        url = davUrl;
        userName = cfg.nextcloudUser;
      };
      thunderbird = {
        enable = true;
        profiles = [ profile ];
      };
    };

    # Contacts (CardDAV, two-way sync with Nextcloud).
    accounts.contact.basePath = ".contacts";
    accounts.contact.accounts.nextcloud = {
      remote = {
        type = "carddav";
        url = davUrl;
        userName = cfg.nextcloudUser;
      };
      thunderbird = {
        enable = true;
        profiles = [ profile ];
      };
    };
  };
}
