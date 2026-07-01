# VHS tape: the op-log options menu (o) with a sticky =limit value arg.
# Catppuccin Mocha; needs CURATE_COLORSCHEME_PATH.
Output oplogmenu.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1200
Set Height 760
Set Padding 16

Hide
Type "export CURATE_COLORSCHEME=catppuccin; export REPO=$(bash $CURATE_ROOT/scripts/demo-repo.sh); cd $REPO; export HOME=$REPO/.home" Enter
# generate several operations so a limit is meaningful
Type "jj describe -m 'feat: route hunks' >/dev/null 2>&1; jj new >/dev/null 2>&1; echo x>>hunks.lua; jj squash >/dev/null 2>&1; jj new >/dev/null 2>&1; jj describe -m more >/dev/null 2>&1" Enter
Type "nvim -u $CURATE_ROOT/scripts/nvim-demo-init.lua -c 'Curate oplog'" Enter
Sleep 2s
Show

Sleep 700ms
Type "o"
Sleep 1000ms
Screenshot oplog-menu.png
Sleep 400ms
# set the =limit value arg to 4
Type "n"
Sleep 500ms
Type "4"
Sleep 300ms
Enter
Sleep 900ms
Screenshot oplog-menu-arg.png
Sleep 400ms
# apply → the op-log re-renders capped to 4
Type "a"
Sleep 1200ms
Screenshot oplog-limited.png
Sleep 600ms
