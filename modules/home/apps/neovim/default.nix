{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.neovim;

  # Treesitter parsers + queries, provided reproducibly by Nix instead of the
  # archived nvim-treesitter (which used to compile them at runtime). Placed on
  # the runtimepath under $XDG_DATA_HOME/nvim/site; highlighting is Neovim
  # 0.12's built-in treesitter (see lua/plugins/treesitter.lua).
  tsg = pkgs.tree-sitter.builtGrammars;

  # Neovim-language name -> nixpkgs grammar. Each grammar supplies both its
  # parser and its own queries, kept as a matched set from a single source so
  # the two can never drift. (Pairing a Nix parser with Neovim 0.12's *bundled*
  # queries instead breaks whenever the two grammar revisions disagree — e.g.
  # lua's `operator:` field, absent from the tree-sitter-grammars fork nixpkgs
  # ships, made every lua buffer throw. Grammar-own queries sidestep that.)
  # luadoc/luap/vimdoc are intentionally dropped: no standalone nixpkgs grammar;
  # vimdoc keeps Neovim's legacy help highlighting.
  #
  # Revisit if upstream settles on a canonical parser+query story for core
  # treesitter (post nvim-treesitter archival): neovim/neovim#39006. If Neovim
  # starts shipping/curating queries that pair with a known parser set, the
  # grammar-own-queries approach here can likely be simplified or dropped.
  grammars = {
    bash = tsg.tree-sitter-bash;
    c = tsg.tree-sitter-c;
    cpp = tsg.tree-sitter-cpp;
    diff = tsg.tree-sitter-diff;
    erlang = tsg.tree-sitter-erlang;
    fish = tsg.tree-sitter-fish;
    git_config = tsg.tree-sitter-git-config;
    git_rebase = tsg.tree-sitter-git-rebase;
    gitattributes = tsg.tree-sitter-gitattributes;
    gitcommit = tsg.tree-sitter-gitcommit;
    gitignore = tsg.tree-sitter-gitignore;
    hyprlang = tsg.tree-sitter-hyprlang;
    json = tsg.tree-sitter-json;
    lua = tsg.tree-sitter-lua;
    markdown = tsg.tree-sitter-markdown;
    markdown_inline = tsg.tree-sitter-markdown-inline;
    nix = tsg.tree-sitter-nix;
    proto = tsg.tree-sitter-proto;
    python = tsg.tree-sitter-python;
    query = tsg.tree-sitter-query; # for editing treesitter .scm query files
    regex = tsg.tree-sitter-regex;
    rust = tsg.tree-sitter-rust;
    toml = tsg.tree-sitter-toml;
    vim = tsg.tree-sitter-vim;
    xml = tsg.tree-sitter-xml;
    yaml = tsg.tree-sitter-yaml;
  };

  treesitterRuntime = pkgs.runCommand "nvim-treesitter-runtime" { } (
    ''
      mkdir -p $out/parser $out/queries
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (lang: drv: ''
        ln -s ${drv}/parser $out/parser/${lang}.so
        mkdir -p $out/queries/${lang}
        # Grammars store queries either flat at queries/*.scm or nested one
        # level under queries/<name>/*.scm (e.g. hyprlang, query). Harvest both
        # into queries/${lang}/; first file wins on the rare basename collision.
        for q in ${drv}/queries/*.scm ${drv}/queries/*/*.scm; do
          [ -e "$q" ] || continue
          dest=$out/queries/${lang}/$(basename "$q")
          [ -e "$dest" ] || ln -s "$q" "$dest"
        done
      '') grammars
    )
  );
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

    # Nix-provided treesitter parsers + queries on the runtimepath. Neovim adds
    # $XDG_DATA_HOME/nvim/site to 'runtimepath' by default, so parsers land in
    # parser/<lang>.so and queries in queries/<lang>/.
    xdg.dataFile."nvim/site/parser".source = "${treesitterRuntime}/parser";
    xdg.dataFile."nvim/site/queries".source = "${treesitterRuntime}/queries";
  };
}
