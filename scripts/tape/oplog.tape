# VHS tape: the op-log time machine.
Output oplog.gif
Set Theme "TokyoNight"
Set FontSize 16
Set Width 1200
Set Height 760
Set Padding 14

Hide
Type "export REPO=$(bash $CURATE_ROOT/scripts/demo-repo.sh); cd $REPO; export HOME=$REPO/.home" Enter
# Generate a few operations to populate the log.
Type "jj describe -m 'feat: route hunks' >/dev/null 2>&1; jj new >/dev/null 2>&1; echo x>>hunks.lua; jj squash >/dev/null 2>&1; jj new >/dev/null 2>&1" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate oplog'" Enter
Sleep 2s
Show

Sleep 1s
Screenshot oplog.png
Sleep 500ms
