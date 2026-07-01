# VHS tape: the abandon transient (k) with sticky args, from the log. Catppuccin
# Mocha; needs CURATE_COLORSCHEME_PATH.
Output abandonmenu.gif
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
Type "j"
Sleep 300ms
Type "k"
Sleep 1200ms
Screenshot abandon-menu.png
Sleep 400ms
# toggle --restore-descendants
Type "d"
Sleep 1000ms
Screenshot abandon-menu-arg.png
Sleep 600ms
Escape
Sleep 300ms
