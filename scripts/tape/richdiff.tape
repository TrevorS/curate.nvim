# VHS tape: rich diff — treesitter syntax highlighting + intra-line word
# emphasis, under Catppuccin Mocha. The theme is a nvim colorscheme, so set
# CURATE_COLORSCHEME_PATH to a catppuccin/nvim checkout before running:
#   CURATE_COLORSCHEME_PATH=~/plugins/catppuccin scripts/screenshot.sh scripts/tape/richdiff.tape
Output richdiff.gif
Set Theme "Catppuccin Mocha"
Set FontSize 17
Set Width 1200
Set Height 780
Set Padding 16

Hide
Type "export REPO=$(bash $CURATE_ROOT/scripts/demo-repo-config.sh); cd $REPO; export HOME=$REPO/.home" Enter
Type "export CURATE_COLORSCHEME=catppuccin" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate status' -c 'only'" Enter
Sleep 3s
Show

# Open the diff-editor over the config tweak.
Sleep 600ms
Type "x"
Sleep 2500ms
Screenshot richdiff.png
Sleep 500ms
