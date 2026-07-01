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

-- ── network: pull (fetch, then restack onto the updated trunk) ──

--- The magit-style "pull": jj has no `pull`, so fetch and then rebase the local
--- branch of @ onto the freshly-moved `trunk()`. A fetch failure aborts before
--- any rewrite; when @ is already on trunk the rebase is a clean no-op.
---@param fetch_args string[]  the git-fetch argv (default vs all-remotes)
---@param label string
local function pull_with(fetch_args, label)
  jj.run(fetch_args, function(r)
    if r.code ~= 0 then
      vim.notify("curate: fetch failed: " .. vim.trim(r.stderr), vim.log.levels.WARN)
      util.refresh_all()
      return
    end
    util.mutate(jj, { "rebase", "-b", "@", "-d", "trunk()" }, label)
  end)
end

--- u — pull: fetch the default remote, then rebase @'s branch onto trunk().
function M.pull()
  pull_with({ "git", "fetch" }, "pulled (fetched + rebased onto trunk)")
end

--- U — pull from all remotes, then rebase @'s branch onto trunk().
function M.pull_all()
  pull_with({ "git", "fetch", "--all-remotes" }, "pulled all remotes (rebased onto trunk)")
end

-- ── network: push ──

--- Run `jj git push` with the given base args plus any transient flags.
---@param base string[]  e.g. {} or { "--all" }
---@param flags string[]|nil  sticky-arg flags from the push transient
---@param label string
local function git_push(base, flags, label)
  local args = vim.list_extend({ "git", "push" }, base)
  util.mutate(jj, vim.list_extend(args, flags or {}), label)
end

--- Push tracked bookmarks with unpushed changes to their remotes.
function M.push(flags)
  git_push({}, flags, "pushed")
end

--- Push the change under the cursor (or @) as a new auto-named bookmark
--- (push-<change-id>). The 80% "publish what I'm working on" gesture.
function M.push_change(flags)
  local id = util.cursor_change_id() or "@"
  git_push({ "--change", id }, flags, "pushed " .. id:sub(1, 8))
end

--- Push every bookmark (including new ones) to the default remote.
function M.push_all(flags)
  git_push({ "--all" }, flags, "pushed all bookmarks")
end

--- P — the push transient: a sticky `--allow-new` arg over the push actions,
--- the poster child for the transient engine's toggleable flags.
function M.push_menu()
  transient.open({
    title = "push (git)",
    items = {
      { key = "n", arg = true, flag = "--allow-new", label = "allow new bookmarks" },
      { key = "p", label = "push tracked bookmarks", run = M.push },
      { key = "c", label = "push this change as a new bookmark", run = M.push_change },
      { key = "P", label = "push all bookmarks", run = M.push_all },
    },
  })
end

-- ── the sync transient (network) ──

--- f — the sync menu: fetch / fetch-all / push / push-change / push-all.
function M.menu()
  transient.open({
    title = "sync (git)",
    items = {
      { key = "f", label = "fetch (default remote)", run = M.fetch },
      { key = "F", label = "fetch all remotes", run = M.fetch_all },
      { key = "u", label = "pull (fetch + rebase onto trunk)", run = M.pull },
      { key = "U", label = "pull all remotes (+ rebase)", run = M.pull_all },
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
