{
  mkShell,
  pkgs,
  ...
}:
let
  # lua-language-server config for editing modules/home/apps/hyprland/hyprland.lua:
  # declare the `hl` global and point at Hyprland's bundled LuaCATS stubs for
  # full type info/autocomplete. The stub path is a version-specific store path,
  # so this is generated (not committed) and tracks the pinned Hyprland.
  luarc = pkgs.writeText "hyprland-luarc.json" (
    builtins.toJSON {
      diagnostics.globals = [ "hl" ];
      workspace.library = [ "${pkgs.hyprland}/share/hypr/stubs" ];
    }
  );
in
mkShell {
  # Regenerate the (gitignored) .luarc.json on shell entry. The repo root is
  # resolved at runtime, so no checkout path is hardcoded.
  shellHook = ''
    root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
    install -m644 ${luarc} "$root/modules/home/apps/hyprland/.luarc.json"
  '';
}
