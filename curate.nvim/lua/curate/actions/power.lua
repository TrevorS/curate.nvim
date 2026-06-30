-- actions/power.lua — the reserved power surface (P7). The less-common but
-- high-value jj verbs, gathered behind one transient so they don't clutter the
-- everyday grammar: duplicate · parallelize · fix · workspace · annotate.

local jj = require("curate.jj")
local util = require("curate.actions.util")
local transient = require("curate.ui.transient")

local M = {}

--- Z — the power transient.
function M.menu()
  transient.open({
    title = "power",
    items = {
      { key = "d", label = "duplicate this change", run = M.duplicate },
      { key = "p", label = "parallelize (make siblings)", run = M.parallelize },
      { key = "x", label = "fix (run configured formatters)", run = M.fix },
      { key = "a", label = "annotate / blame this file", run = M.annotate },
      { key = "w", label = "workspace menu", run = M.workspace },
    },
  })
end

--- Duplicate the change under the cursor (or @) as a new sibling copy.
function M.duplicate()
  local id = util.cursor_change_id() or "@"
  util.mutate(jj, { "duplicate", "-r", id }, "duplicated " .. id:sub(1, 8))
end

--- Parallelize: turn the marked change and the one under the cursor into
--- siblings (split a linear chain into a fan). Uses the reshape mark if set.
function M.parallelize()
  local cursor = util.cursor_change_id()
  local mark = require("curate.actions.reshape").marked()
  local revs = {}
  if mark then
    revs[#revs + 1] = mark
  end
  if cursor and cursor ~= mark then
    revs[#revs + 1] = cursor
  end
  if #revs < 2 then
    vim.notify(
      "curate: parallelize needs two changes — mark one (m), then run on another",
      vim.log.levels.WARN
    )
    return
  end
  util.mutate(jj, vim.list_extend({ "parallelize" }, revs), "parallelized")
end

--- Fix: run jj's configured formatters/fixers over the change under the cursor.
function M.fix()
  local id = util.cursor_change_id() or "@"
  util.mutate(jj, { "fix", "-s", id }, "fixed " .. id:sub(1, 8))
end

--- Annotate / blame the file in the current (non-curate) window.
function M.annotate()
  require("curate.views.annotate").open({})
end

--- Open the revset workbench (live-recomputing query buffer).
function M.revset()
  require("curate.views.revset").open()
end

--- Workspace sub-transient (add / list / forget).
function M.workspace()
  transient.open({
    title = "workspace",
    items = {
      { key = "a", label = "add a workspace", run = M.workspace_add },
      { key = "l", label = "list workspaces", run = M.workspace_list },
      { key = "f", label = "forget a workspace", run = M.workspace_forget },
    },
  })
end

function M.workspace_add()
  vim.ui.input({ prompt = "new workspace path: " }, function(path)
    if path and path ~= "" then
      util.mutate(jj, { "workspace", "add", path }, "workspace add " .. path)
    end
  end)
end

function M.workspace_list()
  jj.run({ "workspace", "list", "--color=never" }, function(r)
    local body = vim.trim(r.stdout) ~= "" and r.stdout or "(no workspaces)"
    vim.notify("curate workspaces:\n" .. body, vim.log.levels.INFO)
  end)
end

function M.workspace_forget()
  vim.ui.input({ prompt = "workspace to forget: " }, function(name)
    if name and name ~= "" then
      util.mutate(jj, { "workspace", "forget", name }, "workspace forget " .. name)
    end
  end)
end

return M
