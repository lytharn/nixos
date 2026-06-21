{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.neovim;
in
{
  options.${namespace}.apps.neovim = {
    enable = lib.mkEnableOption "neovim";

    flakePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/flake";
      description = ''
        Absolute path to this flake's working checkout. The neovim lua config
        is symlinked from here (via mkOutOfStoreSymlink) rather than copied
        into the read-only Nix store, so it stays live-editable and lazy.nvim
        can rewrite lazy-lock.json in place (`:Lazy update`).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      neovim

      # LSP servers. lua/plugins/lsp.lua configures these but leaves
      # mason-tool-installer's ensure_installed empty, so they are launched
      # from PATH rather than installed by mason (whose prebuilt binaries
      # don't run on NixOS anyway).
      lua-language-server
      marksman
      nixd
      pyright
      ruff
      rust-analyzer # used by rustaceanvim

      # nvim-treesitter (main branch) compiles parsers at runtime via the
      # tree-sitter CLI + a C compiler.
      tree-sitter
      gcc

      # Pickers in snacks.nvim.
      ripgrep
      fd

      # DAP debug adapters (lua/plugins/nvim-dap.lua, rustaceanvim).
      # lldb ships lldb-dap, which nvim-dap looks up via exepath("lldb-dap")
      # for C/C++/Rust debugging.
      lldb
      # nvim-dap-python runs `python3 -m debugpy.adapter`, so debugpy must be
      # importable by the python3 it launches. hiPrio so this debugpy-enabled
      # python3 wins the profile collision against the plain python3 the tmux
      # module also installs (both ship bin/idle, bin/python3, ...).
      (lib.hiPrio (python3.withPackages (ps: [ ps.debugpy ])))
    ];

    home.sessionVariables.EDITOR = "nvim";

    # Symlink to the working checkout, not the store: edits to the lua show up
    # immediately and lazy.nvim can persist lazy-lock.json.
    xdg.configFile."nvim".source =
      config.lib.file.mkOutOfStoreSymlink "${cfg.flakePath}/modules/home/apps/neovim/config";
  };
}
