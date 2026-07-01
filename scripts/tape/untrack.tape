# VHS tape: untrack an ignored, committed build artifact (K) from the status
# tree, Catppuccin Mocha. Needs a catppuccin/nvim checkout at
# CURATE_COLORSCHEME_PATH (else falls back).
Output untrack.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1200
Set Height 720
Set Padding 16

Hide
Type "export CURATE_COLORSCHEME=catppuccin; export REPO=$(bash $CURATE_ROOT/scripts/demo-repo-untrack.sh); cd $REPO; export HOME=$REPO/.home" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate status'" Enter
Sleep 2s
Show

Sleep 800ms
Screenshot untrack-before.png
Sleep 400ms
# land on build.log in the working-copy tree and untrack it
Type "/build.log"
Enter
Sleep 500ms
Type "K"
Sleep 1800ms
Screenshot untrack-after.png
Sleep 600ms
