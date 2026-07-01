# VHS tape: the push transient (P) with a sticky --dry-run arg. Catppuccin
# Mocha; needs a catppuccin/nvim checkout at CURATE_COLORSCHEME_PATH.
Output pushmenu.gif
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
Type "P"
Sleep 1200ms
Screenshot push-menu.png
Sleep 500ms
# toggle the sticky --dry-run arg → [ ] becomes [✓]
Type "d"
Sleep 1200ms
Screenshot push-menu-arg.png
Sleep 800ms
