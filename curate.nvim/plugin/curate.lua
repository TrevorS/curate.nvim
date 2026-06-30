-- plugin/curate.lua — guard · :Curate command · curate:// autocmds (runs once).

if vim.g.loaded_curate then
  return
end
vim.g.loaded_curate = true

-- :Curate [view]  — open a curate surface (defaults to the status home).
vim.api.nvim_create_user_command("Curate", function(a)
  local view = a.args ~= "" and a.args or "status"
  local ok, mod = pcall(require, "curate.views." .. view)
  if not ok then
    vim.notify("curate: unknown view: " .. view, vim.log.levels.ERROR)
    return
  end
  mod.open()
end, {
  nargs = "?",
  complete = function()
    return { "status", "log", "oplog", "evolog", "revset", "process" }
  end,
  desc = "Open a curate view",
})

-- (:checkhealth curate auto-discovers lua/curate/health.lua.)

-- curate://<change_id>/<path> buffers — edit any revision's file (BufReadCmd /
-- BufWriteCmd). Registered once; the heavy lifting is in views/file.lua.
local grp = vim.api.nvim_create_augroup("curate.file", { clear = true })
for _, ev in ipairs({ "BufReadCmd", "BufWriteCmd" }) do
  vim.api.nvim_create_autocmd(ev, {
    group = grp,
    pattern = "curate://*/*",
    callback = function(a)
      local fn = ev == "BufReadCmd" and "read" or "write"
      require("curate.views.file")[fn](a.buf, a.match)
    end,
  })
end
