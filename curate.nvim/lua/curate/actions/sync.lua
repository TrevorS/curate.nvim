-- actions/sync.lua — SUPPORTING: get curated work out. bookmarks · git
-- push/fetch · remote tracking. We don't out-feature anyone here; just enough
-- to publish the curated result and keep bookmarks in sync with remotes.

local jj = require("curate.jj")
local util = require("curate.actions.util")
local transient = require("curate.ui.transient")

local M = {}

-- ── network: fetch ──

--- Fetch from the default remote.
function M.fetch()
  util.mutate(jj, { "git", "fetch" }, "fetched")
end

--- Fetch from every configured remote.
function M.fetch_all()
  util.mutate(jj, { "git", "fetch", "--all-remotes" }, "fetched all remotes")
end

-- ── network: push ──

--- Push tracked bookmarks with unpushed changes to their remotes.
function M.push()
  util.mutate(jj, { "git", "push" }, "pushed")
end

--- Push the change under the cursor (or @) as a new auto-named bookmark
--- (push-<change-id>). The 80% "publish what I'm working on" gesture.
function M.push_change()
  local id = util.cursor_change_id() or "@"
  util.mutate(jj, { "git", "push", "--change", id }, "pushed " .. id:sub(1, 8))
end

--- Push every bookmark (including new ones) to the default remote.
function M.push_all()
  util.mutate(jj, { "git", "push", "--all" }, "pushed all bookmarks")
end

-- ── the sync transient (network) ──

--- f — the sync menu: fetch / fetch-all / push / push-change / push-all.
function M.menu()
  transient.open({
    title = "sync (git)",
    items = {
      { key = "f", label = "fetch (default remote)", run = M.fetch },
      { key = "F", label = "fetch all remotes", run = M.fetch_all },
      { key = "p", label = "push tracked bookmarks", run = M.push },
      { key = "c", label = "push this change as a new bookmark", run = M.push_change },
      { key = "P", label = "push all bookmarks", run = M.push_all },
    },
  })
end

-- ── bookmarks ──

--- b — the bookmark transient (set / tug / delete / forget / track / list).
function M.bookmark()
  transient.open({
    title = "bookmark",
    items = {
      { key = "s", label = "set bookmark here", run = M.set },
      { key = "t", label = "tug (move to @)", run = M.tug },
      { key = "d", label = "delete bookmark (propagates on push)", run = M.delete },
      { key = "f", label = "forget bookmark (local only)", run = M.forget },
      { key = "k", label = "track remote bookmark", run = M.track },
      { key = "u", label = "untrack remote bookmark", run = M.untrack },
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

--- Delete a bookmark and propagate the deletion to remotes on the next push.
function M.delete()
  vim.ui.input({ prompt = "bookmark to delete: " }, function(name)
    if name and name ~= "" then
      util.mutate(jj, { "bookmark", "delete", name }, "deleted " .. name)
    end
  end)
end

--- Forget a bookmark locally (without scheduling a remote deletion).
function M.forget()
  vim.ui.input({ prompt = "bookmark to forget: " }, function(name)
    if name and name ~= "" then
      util.mutate(jj, { "bookmark", "forget", name }, "forgot " .. name)
    end
  end)
end

--- Start tracking a remote bookmark (name@remote), so it follows on fetch/push.
function M.track()
  vim.ui.input({ prompt = "remote bookmark to track (name@remote): " }, function(spec)
    if spec and spec ~= "" then
      util.mutate(jj, { "bookmark", "track", spec }, "tracking " .. spec)
    end
  end)
end

--- Stop tracking a remote bookmark.
function M.untrack()
  vim.ui.input({ prompt = "remote bookmark to untrack (name@remote): " }, function(spec)
    if spec and spec ~= "" then
      util.mutate(jj, { "bookmark", "untrack", spec }, "untracked " .. spec)
    end
  end)
end

function M.list()
  jj.run({ "bookmark", "list", "--all-remotes", "--color=never" }, function(r)
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
