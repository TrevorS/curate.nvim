-- keymap.lua — the registry (data, not code). One table feeds ftplugin maps,
-- which-key labels, and the generated cheatsheet. (§I + §2 of the spec.)
--
-- Each entry: { lhs, "module.fn", "label", rw = <rewrites history?> }

local M = {}

-- Built-in actions handled directly (not action-module dispatch).
local SPECIAL = {
  ["view.refresh"] = function()
    local v = M._active_view()
    if v then
      v:refresh()
    end
  end,
  ["view.fold"] = function()
    local v = M._active_view()
    if v and v.toggle_fold then
      v:toggle_fold()
    end
  end,
  ["view.enter"] = function()
    local v = M._active_view()
    if v and v.on_enter then
      v:on_enter()
    end
  end,
  ["view.diff"] = function()
    local v = M._active_view()
    if v and v.show_diff then
      v:show_diff()
    end
  end,
  ["view.close"] = function()
    local v = M._active_view()
    if v then
      v:close()
    end
  end,
  ["view.cheatsheet"] = function()
    M.cheatsheet()
  end,
}

---@type table<string, table[]>
M.maps = {
  ["curate-status"] = {
    { "<CR>", "view.enter", "edit / expand under cursor" },
    { "<Tab>", "view.fold", "cycle fold (file → hunks)" },
    { "n", "name.new", "new change" },
    { "d", "name.describe", "describe" },
    { "c", "name.commit", "commit (describe + new)" },
    { "A", "route.absorb", "absorb working copy", rw = true },
    { "s", "route.squash", "squash → parent", rw = true },
    { "S", "route.squash_interactive", "squash interactively", rw = true },
    { "x", "route.split_interactive", "split interactively", rw = true },
    { "=", "route.restore", "restore hunk/file from parent", rw = true },
    { "m", "reshape.mark", "mark target" },
    { "r", "reshape.rebase", "rebase", rw = true },
    { "b", "sync.bookmark", "bookmark menu" },
    { "o", "trust.oplog", "op-log" },
    { "u", "trust.undo", "undo" },
    { "L", "trust.evolog", "evolog" },
    { "g", "view.refresh", "refresh" },
    { "$", "sync.process", "process buffer" },
    { "?", "view.cheatsheet", "which-key / cheatsheet" },
    { "q", "view.close", "close" },
  },
  ["curate-log"] = {
    { "<CR>", "name.edit_here", "edit this change" },
    { "n", "name.new", "new change" },
    { "d", "name.describe", "describe" },
    { "m", "reshape.mark", "mark rebase source/target" },
    { "r", "reshape.rebase", "rebase", rw = true },
    { "s", "route.squash", "squash → parent", rw = true },
    { "b", "sync.bookmark", "bookmark menu" },
    { "u", "trust.undo", "undo" },
    { "o", "trust.oplog", "op-log" },
    { "g", "view.refresh", "refresh" },
    { "q", "view.close", "close" },
  },
  ["curate-oplog"] = {
    { "<CR>", "view.enter", "restore to op (confirm)" },
    { "=", "view.diff", "diff this op caused" },
    { "g-", "trust.undo", "undo walk" },
    { "g+", "trust.redo", "redo walk" },
    { "L", "trust.evolog", "evolog of change" },
    { "u", "trust.undo", "undo last (global)" },
    { "g", "view.refresh", "refresh" },
    { "q", "view.close", "close" },
  },
}

--- Find the active curate View for the current buffer.
---@return curate.View|nil
function M._active_view()
  local View = require("curate.ui.view")
  local buf = vim.api.nvim_get_current_buf()
  for _, kind in ipairs({ "status", "log", "oplog", "evolog", "process" }) do
    local v = View.get(kind)
    if v and v.buf == buf then
      return v
    end
  end
  return nil
end

-- The last mutating (rewrites-history) action, for dot-repeat.
M._last = nil

--- Dispatch a registry action string ("module.fn").
---@param action string
---@param rw boolean|nil  rewrites history? recorded for `.` repeat
local function dispatch(action, rw)
  if action == "view.repeat" then
    if M._last then
      dispatch(M._last, true)
    end
    return
  end
  if SPECIAL[action] then
    SPECIAL[action]()
    return
  end
  -- NB: [%w_] not %w — action fns like `split_interactive` contain underscores,
  -- which %w excludes, so the bare-%w pattern silently dropped them.
  local mod, fn = action:match("^([%w_]+)%.([%w_]+)$")
  if not mod then
    return
  end
  local ok, m = pcall(require, "curate.actions." .. mod)
  if not ok or type(m[fn]) ~= "function" then
    vim.notify("curate: not yet available: " .. action, vim.log.levels.INFO)
    return
  end
  if rw then
    M._last = action -- remember the last history-rewriting gesture
  end
  m[fn]()
end

--- Install buffer-local maps via FileType autocmds for each registered ft.
function M.install()
  local grp = vim.api.nvim_create_augroup("curate.keymap", { clear = true })
  for ft, list in pairs(M.maps) do
    vim.api.nvim_create_autocmd("FileType", {
      group = grp,
      pattern = ft,
      callback = function(a)
        for _, entry in ipairs(list) do
          local lhs, action, label, rw = entry[1], entry[2], entry[3], entry.rw
          vim.keymap.set("n", lhs, function()
            dispatch(action, rw)
          end, { buffer = a.buf, nowait = true, silent = true, desc = "curate: " .. label })
        end
        -- `.` repeats the last history-rewriting gesture (absorb/squash/split…).
        vim.keymap.set("n", ".", function()
          dispatch("view.repeat")
        end, { buffer = a.buf, nowait = true, silent = true, desc = "curate: repeat last" })
      end,
    })
  end
  M._install_which_key()
end

--- Optional which-key labels (only if which-key.nvim is present).
function M._install_which_key()
  local ok, wk = pcall(require, "which-key")
  if not ok then
    return
  end
  -- which-key reads our labels; registration is best-effort and version-tolerant.
  pcall(function()
    for _, list in pairs(M.maps) do
      local spec = {}
      for _, e in ipairs(list) do
        spec[#spec + 1] = { e[1], desc = e[3] }
      end
      if wk.add then
        wk.add(spec)
      end
    end
  end)
end

--- ? — render the keymap for the current buffer's filetype as a cheatsheet.
function M.cheatsheet()
  local ft = vim.bo.filetype
  local list = M.maps[ft] or M.maps["curate-status"]
  local lines = { " curate · " .. ft, "" }
  for _, e in ipairs(list) do
    local flag = e.rw and "  ⚠ rewrites" or ""
    lines[#lines + 1] = string.format("  %-7s %s%s", e[1], e[3], flag)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, #l)
  end
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    anchor = "SE",
    row = vim.o.lines - 2,
    col = vim.o.columns - 2,
    width = width + 2,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = " keys ",
  })
  for _, k in ipairs({ "q", "<Esc>", "?" }) do
    vim.keymap.set("n", k, function()
      pcall(vim.api.nvim_win_close, win, true)
    end, { buffer = buf, nowait = true })
  end
end

return M
