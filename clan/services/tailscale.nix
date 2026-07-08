{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/tailscale";
  manifest.description = "Tailscale on member machines, enrolled from a clan-var auth key";
  manifest.readme = "Joins each member machine to the tailnet. Also declares the placeholder auth-key var generator (enrolment is one-time; all hosts are already enrolled). Applied to every host.";

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

            # Auth key: only read on first enrolment. Every host here is already enrolled with
            # persistent state, so this placeholder is never actually used — it just satisfies
            # authKeyFile without prompting.
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
