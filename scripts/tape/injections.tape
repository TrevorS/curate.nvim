# VHS tape: treesitter injections in the diff — Markdown with a ```lua fence and
# a Lua file with a vim.cmd([[ ... ]]) block, under Catppuccin Mocha. The theme
# is a nvim colorscheme, so set CURATE_COLORSCHEME_PATH to a catppuccin/nvim
# checkout before running:
#   CURATE_COLORSCHEME_PATH=~/plugins/catppuccin scripts/screenshot.sh scripts/tape/injections.tape
Output injections.gif
Set Theme "Catppuccin Mocha"
Set FontSize 15
Set Width 1300
Set Height 1000
Set Padding 16

Hide
Type "export REPO=$(bash $CURATE_ROOT/scripts/demo-repo-inject.sh); cd $REPO; export HOME=$REPO/.home" Enter
Type "export CURATE_COLORSCHEME=catppuccin" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate status' -c 'only'" Enter
Sleep 3s
Show

# Open the diff-editor: Markdown, Lua-in-fence, and vimscript-in-vim.cmd at once.
Sleep 600ms
Type "x"
Sleep 2500ms
Screenshot injections.png
Sleep 500ms
