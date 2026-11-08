{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.neovim;

  # Treesitter parsers + queries from Nix, put on the runtimepath under
  # $XDG_DATA_HOME/nvim/site for Neovim's built-in treesitter.
  tsg = pkgs.tree-sitter.builtGrammars;

  # Neovim language name -> nixpkgs grammar. Each grammar's parser is paired
  # with that grammar's own queries: Neovim's bundled queries break whenever
  # they target a different grammar revision than the parser (e.g. lua's
  # `operator:` field made every lua buffer throw). Revisit if Neovim starts
  # shipping queries matched to a known parser set.
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
    yaml = tsg.tree-sitter-yaml;
  };

  # Grammars whose queries only extend another language's: tree-sitter-cpp's
  # highlights.scm leaves strings, comments and numbers to tree-sitter-c's.
  # Neovim expresses that with an `; inherits: <lang>` modeline, which upstream
  # files don't carry, so it's prepended here.
  queryInherits = {
    cpp = "c";
  };

  treesitterRuntime = pkgs.runCommand "nvim-treesitter-runtime" { } (
    ''
      mkdir -p $out/parser $out/queries
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (lang: drv: ''
        ln -s ${drv}/parser $out/parser/${lang}.so
        mkdir -p $out/queries/${lang}
        modeline=${
          lib.escapeShellArg (if queryInherits ? ${lang} then "; inherits: ${queryInherits.${lang}}" else "")
        }
        # Grammars store queries either flat at queries/*.scm or nested one
        # level under queries/<name>/*.scm (e.g. hyprlang, query). Harvest both
        # into queries/${lang}/; first file wins on the rare basename collision.
        for q in ${drv}/queries/*.scm ${drv}/queries/*/*.scm; do
          [ -e "$q" ] || continue
          dest=$out/queries/${lang}/$(basename "$q")
          [ -e "$dest" ] && continue
          if [ -n "$modeline" ]; then
            { printf '%s\n' "$modeline"; cat "$q"; } > "$dest"
          else
            ln -s "$q" "$dest"
          fi
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

      # LSP servers, configured in lua/plugins/lsp.lua and started from PATH.
      clang-tools # Includes clangd, clang-format and clang-tidy
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
    # immediately and lazy.nvim can persist lazy-lock.json. Since Nix never reads
    # the dir, clan/services/deploy-report.nix leaves it out of the source it
    # embeds in every system; drop that exclusion if this ever copies it instead.
    xdg.configFile."nvim".source =
      config.lib.file.mkOutOfStoreSymlink "${cfg.flakePath}/modules/home/apps/neovim/config";

    # Nix-provided treesitter parsers + queries on the runtimepath. Neovim adds
    # $XDG_DATA_HOME/nvim/site to 'runtimepath' by default, so parsers land in
    # parser/<lang>.so and queries in queries/<lang>/.
    xdg.dataFile."nvim/site/parser".source = "${treesitterRuntime}/parser";
    xdg.dataFile."nvim/site/queries".source = "${treesitterRuntime}/queries";
  };
}
