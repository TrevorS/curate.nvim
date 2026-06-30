-- views/process.lua — the $ process buffer. A ring log of jj invocations and
-- their failures, so the user can see what curate actually ran (magit's $).

local M = {}

local RING = 200
local entries = {} ---@type { ts:string, args:string, code:integer, stderr:string }[]

--- Record a (usually failed) jj invocation. Called by the runner.
---@param args string[]
---@param r curate.RunResult
function M.log(args, r)
  entries[#entries + 1] = {
    args = table.concat(args, " "),
    code = r.code,
    stderr = vim.trim(r.stderr or ""),
  }
  if #entries > RING then
    table.remove(entries, 1)
  end
end

--- $ — open the process buffer.
function M.open()
  local lines = { "curate process log  (jj invocations · q to close)", "" }
  if #entries == 0 then
    lines[#lines + 1] = "  (nothing logged yet)"
  end
  for i = #entries, 1, -1 do
    local e = entries[i]
    lines[#lines + 1] = string.format("  [%d] jj %s", e.code, e.args)
    if e.stderr ~= "" then
      for _, l in ipairs(vim.split(e.stderr, "\n", { plain = true })) do
        lines[#lines + 1] = "      " .. l
      end
    end
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "curate://process")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "curate-process"
  vim.api.nvim_open_win(buf, true, { split = "below", height = 12 })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
end

return M
