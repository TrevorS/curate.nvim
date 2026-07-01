# VHS tape: the sync transient (f) — now with pull (fetch + rebase). Catppuccin
# Mocha; needs a catppuccin/nvim checkout at CURATE_COLORSCHEME_PATH.
Output syncmenu.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1200
Set Height 720
Set Padding 16

Hide
Type "export CURATE_COLORSCHEME=catppuccin; export REPO=$(bash $CURATE_ROOT/scripts/demo-repo.sh); cd $REPO; export HOME=$REPO/.home" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate status' -c 'only'" Enter
Sleep 2s
Show

Sleep 800ms
Type "f"
Sleep 1400ms
Screenshot sync-menu.png
Sleep 700ms
