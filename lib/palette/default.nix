# Tokyo Night (Night variant) color palette — the single source of truth for
# the theme so applications stay in sync.
#
# Values are raw 6-digit hex WITHOUT a leading "#". Consumers add the form they
# need — see each module for how the alpha byte is appended.
{ ... }:
{
  palette.tokyonight = {
    # Backgrounds and surfaces
    bgDark = "16161e";
    bg = "1a1b26";
    bgHighlight = "292e42";
    bgVisual = "283457";

    # Foregrounds, from brightest to faintest
    fg = "c0caf5";
    fgDark = "a9b1d6";
    dark5 = "737aa2";
    comment = "565f89";
    terminalBlack = "414868";
    fgGutter = "3b4261";

    # Accents
    blue = "7aa2f7";
    cyan = "7dcfff";
    magenta = "bb9af7";
    magenta2 = "ff007c";
    purple = "9d7cd8";
    teal = "1abc9c";
    green = "9ece6a";
    green1 = "73daca";
    yellow = "e0af68";
    orange = "ff9e64";
    red = "f7768e";

    # Diff backgrounds (as used by tokyonight.nvim's `diff` group)
    diffAdd = "20303b";
    diffDelete = "37222c";
    diffChange = "1f2231";
    diffText = "394b70";
  };
}
