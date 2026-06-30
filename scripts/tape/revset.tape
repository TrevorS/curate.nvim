# VHS tape: the curate.nvim revset workbench (P7) — live-recomputing query.
Output revset.gif
Set Theme "TokyoNight"
Set FontSize 16
Set Width 1200
Set Height 760
Set Padding 14

Hide
Type "export REPO=$(bash $CURATE_ROOT/scripts/demo-repo.sh); cd $REPO; export HOME=$REPO/.home" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate revset'" Enter
Sleep 2s
Show

# The workbench opens with the default revset and its matching log below.
Sleep 1s
Screenshot revset-open.png

# Edit the query live → results recompute as we type.
Type "ggA"
Sleep 300ms
Type " | all()"
Sleep 200ms
Escape
Sleep 1200ms
Screenshot revset-all.png
Sleep 500ms
