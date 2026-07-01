# VHS tape: the curate.nvim diff-editor (split mode) with live hunk selection.
Output diffeditor.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1200
Set Height 760
Set Padding 14

Hide
Type "export CURATE_COLORSCHEME=catppuccin; export REPO=$(bash $CURATE_ROOT/scripts/demo-repo.sh); cd $REPO; export HOME=$REPO/.home" Enter
# Give @ a two-hunk diff in one file so split has something to route.
Type "printf 'a\nb\nc\nd\ne\n' > split.txt; jj describe -m base >/dev/null 2>&1; jj new >/dev/null 2>&1" Enter
Type "printf 'A\nb\nc\nD\ne\n' > split.txt" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate status'" Enter
Sleep 2s
Show

# Move cursor onto split.txt's change and trigger interactive split (x).
Sleep 800ms
Type "x"
Sleep 1500ms
Screenshot diffeditor-open.png

# Toggle the second hunk off, then screenshot the selection state.
Type "]c"
Sleep 400ms
Type "]c"
Sleep 400ms
Space
Sleep 800ms
Screenshot diffeditor-selection.png
Sleep 500ms
