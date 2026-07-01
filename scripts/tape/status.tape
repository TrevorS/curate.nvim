# VHS tape: the curate.nvim status home against a real jj repo.
# Run via: scripts/screenshot.sh scripts/tape/status.tape
Output status.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1200
Set Height 760
Set Padding 14

# Build a throwaway repo and launch nvim with the plugin (REPO/HOME exported by the runner env).
Hide
Type "export CURATE_COLORSCHEME=catppuccin; export REPO=$(bash $CURATE_ROOT/scripts/demo-repo.sh); cd $REPO; export HOME=$REPO/.home" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate status'" Enter
Sleep 2s
Show

Sleep 1s
Screenshot status-home.png
Sleep 500ms

# Toggle a fold, then open the cheatsheet.
Type "?"
Sleep 1s
Screenshot status-cheatsheet.png
Sleep 500ms
Escape
Sleep 300ms
