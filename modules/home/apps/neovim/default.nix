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

  # Neovim-language name -> nixpkgs grammar. Split in two: Neovim 0.12 already
  # ships curated highlight queries for these languages, so we provide only the
  # parser and let its bundled queries win.
  coreQueryGrammars = {
    c = tsg.tree-sitter-c;
    lua = tsg.tree-sitter-lua;
    markdown = tsg.tree-sitter-markdown;
    markdown_inline = tsg.tree-sitter-markdown-inline;
    query = tsg.tree-sitter-query; # for editing treesitter .scm query files
    vim = tsg.tree-sitter-vim;
  };
  # For everything else we supply the parser and the grammar's own queries.
  # (luadoc/luap/vimdoc are intentionally dropped: no standalone nixpkgs
  # grammar; vimdoc keeps Neovim's legacy help highlighting.)
  fullGrammars = {
    bash = tsg.tree-sitter-bash;
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
    nix = tsg.tree-sitter-nix;
    proto = tsg.tree-sitter-proto;
    python = tsg.tree-sitter-python;
    regex = tsg.tree-sitter-regex;
    rust = tsg.tree-sitter-rust;
    toml = tsg.tree-sitter-toml;
    xml = tsg.tree-sitter-xml;
    yaml = tsg.tree-sitter-yaml;
  };
  allGrammars = coreQueryGrammars // fullGrammars;

  treesitterRuntime = pkgs.runCommand "nvim-treesitter-runtime" { } (
    ''
      mkdir -p $out/parser $out/queries
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (lang: drv: ''
        ln -s ${drv}/parser $out/parser/${lang}.so
      '') allGrammars
    )
    + lib.concatStrings (
      lib.mapAttrsToList (lang: drv: ''
        mkdir -p $out/queries/${lang}
        for q in ${drv}/queries/*.scm; do
          [ -e "$q" ] && ln -s "$q" $out/queries/${lang}/
        done
      '') fullGrammars
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
