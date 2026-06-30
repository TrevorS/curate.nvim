-- actions/sync.lua — SUPPORTING: get curated work out. bookmark · git push/fetch.
--
-- We don't try to out-feature anyone here; just enough to push the result.

local jj = require("curate.jj")
local util = require("curate.actions.util")
local transient = require("curate.ui.transient")

local M = {}

--- gf — fetch from the default remote.
function M.fetch()
  util.mutate(jj, { "git", "fetch" }, "fetched")
end

--- gp — push unpushed bookmarks to origin.
function M.push()
  util.mutate(jj, { "git", "push" }, "pushed")
end

--- b — the bookmark transient (set / move-to-@ "tug" / delete / list).
function M.bookmark()
  transient.open({
    title = "bookmark",
    items = {
      { key = "s", label = "set bookmark here", run = M.set },
      { key = "t", label = "tug (move to @)", run = M.tug },
      { key = "d", label = "delete bookmark", run = M.delete },
      { key = "l", label = "list bookmarks", run = M.list },
    },
  })
end

--- Set (create/move) a bookmark to the change under the cursor (or @).
function M.set()
  local id = util.cursor_change_id() or "@"
  vim.ui.input({ prompt = "bookmark name: " }, function(name)
    if name and name ~= "" then
      util.mutate(jj, { "bookmark", "set", name, "-r", id }, "bookmark " .. name)
    end
  end)
end

--- Tug: move an existing bookmark forward to @ (the common "advance" gesture).
function M.tug()
  vim.ui.input({ prompt = "bookmark to move to @: " }, function(name)
    if name and name ~= "" then
      util.mutate(
        jj,
        { "bookmark", "set", name, "-r", "@", "--allow-backwards" },
        "tugged " .. name
      )
    end
  end)
end

function M.delete()
  vim.ui.input({ prompt = "bookmark to delete: " }, function(name)
    if name and name ~= "" then
      util.mutate(jj, { "bookmark", "delete", name }, "deleted " .. name)
    end
  end)
end

function M.list()
  jj.run({ "bookmark", "list", "--color=never" }, function(r)
    local lines =
      vim.split(vim.trim(r.stdout) ~= "" and r.stdout or "(no bookmarks)", "\n", { plain = true })
    vim.notify("curate bookmarks:\n" .. table.concat(lines, "\n"), vim.log.levels.INFO)
  end)
end

--- $ — open the process log (recent jj invocations + failures).
function M.process()
  require("curate.views.process").open()
end

return M
