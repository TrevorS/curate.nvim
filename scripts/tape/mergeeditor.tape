# VHS tape: the curate.nvim merge-editor (P4) — 3-way conflict resolution.
Output mergeeditor.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1200
Set Height 760
Set Padding 14

Hide
Type "export CURATE_COLORSCHEME=catppuccin; export REPO=$(bash $CURATE_ROOT/scripts/demo-repo.sh); cd $REPO; export HOME=$REPO/.home" Enter
# Build a real 2-sided conflict: base line2=X; c1 line2=A; c2 line2=B; rebase c2 onto c1.
Type "printf 'line1\nX\nline3\n' > conflict.txt; jj describe -m base >/dev/null 2>&1" Enter
Type "BASE=$(jj log -r @ --no-graph -T 'change_id.short(8)')" Enter
Type "jj new $BASE -m c1 >/dev/null 2>&1; printf 'line1\nA\nline3\n' > conflict.txt; C1=$(jj log -r @ --no-graph -T 'change_id.short(8)')" Enter
Type "jj new $BASE -m c2 >/dev/null 2>&1; printf 'line1\nB\nline3\n' > conflict.txt; C2=$(jj log -r @ --no-graph -T 'change_id.short(8)')" Enter
Type "jj rebase -r $C2 -d $C1 >/dev/null 2>&1" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate status'" Enter
Sleep 2s
Show

# Cursor on the conflicted @ change; open the 3-way merge editor (R).
Sleep 800ms
Type "gg"
Sleep 300ms
Type "R"
Sleep 1800ms
Screenshot mergeeditor-open.png

# Choose the left side for the conflict, then screenshot the resolved state.
Type "]c"
Sleep 400ms
Type "l"
Sleep 1000ms
Screenshot mergeeditor-chosen.png
Sleep 500ms
