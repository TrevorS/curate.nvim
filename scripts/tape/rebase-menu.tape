# VHS tape: the rebase transient (r) with sticky args -e (--skip-emptied) and
# -k (--keep-divergent). Catppuccin Mocha; needs CURATE_COLORSCHEME_PATH.
Output rebasemenu.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1200
Set Height 720
Set Padding 16

Hide
Type "export CURATE_COLORSCHEME=catppuccin; export REPO=$(bash $CURATE_ROOT/scripts/demo-repo.sh); cd $REPO; export HOME=$REPO/.home" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate log'" Enter
Sleep 2s
Show

Sleep 700ms
# mark a source change, move to a destination, open the rebase transient
Type "j"
Sleep 300ms
Type "m"
Sleep 500ms
Type "j"
Sleep 300ms
Type "r"
Sleep 1200ms
Screenshot rebase-menu.png
Sleep 400ms
# toggle --skip-emptied
Type "e"
Sleep 1000ms
Screenshot rebase-menu-arg.png
Sleep 600ms
Escape
Sleep 300ms
