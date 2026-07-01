# VHS tape: the fetch/pull transient (f) with a sticky -a (--all-remotes) arg.
# Catppuccin Mocha; needs CURATE_COLORSCHEME_PATH.
Output fetchpull.gif
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

Sleep 700ms
Type "f"
Sleep 1200ms
Screenshot fetchpull-menu.png
Sleep 400ms
Type "a"
Sleep 1000ms
Screenshot fetchpull-menu-arg.png
Sleep 800ms
