-- actions/files.lua — working-copy file verbs. Today: untrack. jj tracks every
-- non-ignored file automatically, so untracking only sticks once the path is
-- ignored — we surface that requirement instead of a raw jj error.

local jj = require("curate.jj")
local util = require("curate.actions.util")

local M = {}

--- K — stop tracking the file under the cursor in the status diff tree.
--- `jj file untrack` requires the path already be ignored (.gitignore /
--- .git/info/exclude), else jj re-adds it; we hint that on failure.
function M.untrack()
  local t = util.cursor_target()
  if not (t and t.type == "file" and t.file) then
    vim.notify("curate: put the cursor on a file to untrack", vim.log.levels.WARN)
    return
  end
  local path = t.file.path
  jj.run({ "file", "untrack", path }, function(r)
    if r.code ~= 0 then
      vim.notify(
        ("curate: untrack %s failed — is it in .gitignore?\n%s"):format(path, vim.trim(r.stderr)),
        vim.log.levels.WARN
      )
    else
      vim.notify("curate: untracked " .. path, vim.log.levels.INFO)
    end
    util.refresh_all()
  end)
end

return M
