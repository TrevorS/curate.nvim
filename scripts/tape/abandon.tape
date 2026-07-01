# VHS tape: abandon a change (D → menu → k) from the log, Catppuccin Mocha. Needs a
# catppuccin/nvim checkout at CURATE_COLORSCHEME_PATH (else falls back).
Output abandon.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1200
Set Height 720
Set Padding 16

Hide
Type "export CURATE_COLORSCHEME=catppuccin; export REPO=$(bash $CURATE_ROOT/scripts/demo-repo-abandon.sh); cd $REPO; export HOME=$REPO/.home" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate log'" Enter
Sleep 2s
Show

Sleep 800ms
Screenshot abandon-before.png
Sleep 400ms
# land on the scratch change, open the abandon menu (D), and execute (k)
Type "/scratch experiment"
Enter
Sleep 500ms
Type "D"
Sleep 1000ms
Type "k"
Sleep 1800ms
Screenshot abandon-after.png
Sleep 600ms
