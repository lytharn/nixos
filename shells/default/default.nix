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
  hyprlandCfg = {
    diagnostics.globals = [ "hl" ];
    workspace.library = [ "${pkgs.hyprland}/share/hypr/stubs" ];
  };

  # Same idea for editing modules/home/apps/neovim/config: in Neovim, lazydev
  # supplies the `vim`/`Snacks` globals plus the Neovim runtime and plugin
  # types, so there are no warnings. Outside Neovim (standalone
  # `lua-language-server --check`) those are missing, so point workspace.library
  # at the pinned Neovim's bundled runtime types (and `${3rd}/luv` for vim.uv)
  # and declare the globals lazydev would otherwise inject. The Neovim store
  # path is version-specific, so this is generated (not committed) and tracks
  # nixpkgs.
  neovimCfg = {
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
  };

  # lua-language-server loads exactly one .luarc.json per LSP *workspace folder*
  # and has no include/extends — the loader is a plain JSON decode. A tool that
  # opens the repo root as its workspace (Claude Code's built-in LSP does) reads
  # neither of the two files above, so every Lua file it looks at reports
  # `Undefined global vim` / `hl`. Give the root the union of the two; derived
  # from the same attrsets so there is nothing to keep in sync by hand.
  #
  # Neovim is unaffected: nvim-lspconfig roots lua_ls at the *nearest* ancestor
  # holding a root marker, and the two files above sit closer to their own Lua
  # than this one does, so those subtrees keep their narrower config. The union
  # is deliberately the looser of the two — it declares every global everywhere
  # and indexes both libraries — which is the right trade for a workspace that
  # spans both subtrees plus Lua belonging to neither.
  rootCfg = {
    inherit (neovimCfg) runtime;
    diagnostics.globals = hyprlandCfg.diagnostics.globals ++ neovimCfg.diagnostics.globals;
    workspace = {
      inherit (neovimCfg.workspace) checkThirdParty;
      library = hyprlandCfg.workspace.library ++ neovimCfg.workspace.library;
    };
  };

  mkLuarc = name: cfg: pkgs.writeText name (builtins.toJSON cfg);
in
mkShell {
  # clan CLI, so `clan machines …` / `clan vars …` are on PATH via direnv on `cd`.
  packages = [ inputs.clan-core.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli ];

  # Regenerate the (gitignored) .luarc.json files on shell entry. The repo root
  # is resolved at runtime, so no checkout path is hardcoded.
  shellHook = ''
    root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
    install -m644 ${mkLuarc "hyprland-luarc.json" hyprlandCfg} "$root/modules/home/apps/hyprland/.luarc.json"
    install -m644 ${mkLuarc "neovim-luarc.json" neovimCfg} "$root/modules/home/apps/neovim/config/.luarc.json"
    install -m644 ${mkLuarc "root-luarc.json" rootCfg} "$root/.luarc.json"
  '';
}
