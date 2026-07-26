{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/tailscale";
  manifest.description = "Tailscale on member machines, enrolled from a clan-var auth key";
  manifest.readme = ''
    Joins each member machine to the tailnet. Also declares the placeholder auth-key var
    generator: real Tailscale auth keys expire, so none is baked in — enrolment is a one-time
    manual step (`tailscale up`). After a wipe/reinstall a host must be re-enrolled by hand;
    see README "Installing a new host". Applied to every host.
  '';

  roles.default = {
    description = "Machines joined to the tailnet";
    perInstance =
      { ... }:
      {
        nixosModule =
          { config, pkgs, ... }:
          {
            services.tailscale = {
              enable = true;
              authKeyFile = config.clan.core.vars.generators.tailscale.files.authkey.path;
              # Direct peer-to-peer connections.
              openFirewall = true;
              # Discover tailscale-advertised routes/services (needed to reach serx's services).
              extraSetFlags = [ "--accept-routes" ];
            };

            # Auth key: only read on first enrolment. Real Tailscale keys expire, so this ships a
            # throwaway placeholder — enrolment is done manually once (`sudo tailscale up --reset
            # --accept-routes`). On an already-enrolled host the persistent state means this is
            # never read; after a wipe/reinstall the placeholder can't auto-enrol and the
            # autoconnect unit fails until you re-run `tailscale up` by hand (see README).
            clan.core.vars.generators.tailscale = {
              files.authkey = { };
              runtimeInputs = [
                pkgs.openssl
                pkgs.coreutils
              ];
              script = ''openssl rand -base64 32 | tr -d "\n" > "$out"/authkey'';
            };
          };
      };
  };
}
