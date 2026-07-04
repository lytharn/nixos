{
  mkShell,
  pkgs,
  inputs,
  ...
}:
let
  # lua-language-server config for editing modules/home/apps/hyprland/hyprland.lua:
  # declare the `hl` global and point at Hyprland's bundled LuaCATS stubs for
  # full type info/autocomplete. The stub path is a version-specific store path,
  # so this is generated (not committed) and tracks the pinned Hyprland.
  hyprlandLuarc = pkgs.writeText "hyprland-luarc.json" (
    builtins.toJSON {
      diagnostics.globals = [ "hl" ];
      workspace.library = [ "${pkgs.hyprland}/share/hypr/stubs" ];
    }
  );

  # Same idea for editing modules/home/apps/neovim/config: in Neovim, lazydev
  # supplies the `vim`/`Snacks` globals plus the Neovim runtime and plugin
  # types, so there are no warnings. Outside Neovim (standalone
  # `lua-language-server --check`) those are missing, so point workspace.library
  # at the pinned Neovim's bundled runtime types (and `${3rd}/luv` for vim.uv)
  # and declare the globals lazydev would otherwise inject. The Neovim store
  # path is version-specific, so this is generated (not committed) and tracks
  # nixpkgs.
  neovimLuarc = pkgs.writeText "neovim-luarc.json" (
    builtins.toJSON {
      runtime.version = "LuaJIT";
      diagnostics.globals = [
        "vim"
        "Snacks"
      ];
      workspace = {
        checkThirdParty = false;
        library = [
          "${pkgs.neovim-unwrapped}/share/nvim/runtime/lua"
          "\${3rd}/luv/library"
        ];
      };
    }
  );
in
mkShell {
  # clan CLI, so `clan machines …` / `clan vars …` are on PATH via direnv on `cd`.
  packages = [ inputs.clan-core.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli ];

  # Regenerate the (gitignored) .luarc.json files on shell entry. The repo root
  # is resolved at runtime, so no checkout path is hardcoded.
  shellHook = ''
    root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
    install -m644 ${hyprlandLuarc} "$root/modules/home/apps/hyprland/.luarc.json"
    install -m644 ${neovimLuarc} "$root/modules/home/apps/neovim/config/.luarc.json"
  '';
}
