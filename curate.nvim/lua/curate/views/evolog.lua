-- views/evolog.lua — per-change history across rewrites (jj evolog).
--
-- Since change-ids are stable, evolog shows how a change evolved over amends,
-- squashes and rebases — how you recover "I squashed away a hunk three rewrites
-- ago." For v1 we render jj's own evolog output (its template context differs
-- from log/commit, so we don't re-template it).

local jj = require("curate.jj")

local M = {}

--- L — open the evolog for a change.
---@param change_id string
function M.open(change_id)
  jj.run({ "evolog", "-r", change_id, "--color=never" }, function(r)
    if r.code ~= 0 then
      vim.notify("curate: evolog failed: " .. (r.stderr or ""), vim.log.levels.WARN)
      return
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "curate://evolog/" .. change_id:sub(1, 8))
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(r.stdout or "", "\n", { plain = true }))
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "curate-evolog"
    vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = math.floor(vim.o.columns * 0.7),
      height = math.floor(vim.o.lines * 0.6),
      row = math.floor(vim.o.lines * 0.2),
      col = math.floor(vim.o.columns * 0.15),
      border = "rounded",
      title = " evolog · " .. change_id:sub(1, 8) .. " ",
      style = "minimal",
    })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
    vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, nowait = true })
  end)
end

return M
