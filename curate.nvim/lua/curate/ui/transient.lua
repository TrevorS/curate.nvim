-- ui/transient.lua — the popup engine (args · sticky · dispatch).
--
-- A minimal magit-style transient: a floating menu of single-key actions that
-- self-documents. Used by the rebase/git menus and as the `?` which-key
-- fallback when which-key.nvim is not installed.

local M = {}

---@class curate.TransientItem
---@field key string
---@field label string
---@field run fun()|nil
---@field arg boolean|nil   sticky toggle argument rather than an action

---@class curate.TransientSpec
---@field title string
---@field items curate.TransientItem[]

---@param spec curate.TransientSpec
function M.open(spec)
  local lines, width = {}, #spec.title
  lines[1] = "  " .. spec.title
  lines[2] = ""
  local keymap = {}
  for _, it in ipairs(spec.items) do
    local prefix = it.arg and "-" or " "
    local line = string.format("  %s %-3s %s", prefix, it.key, it.label)
    lines[#lines + 1] = line
    width = math.max(width, #line)
    keymap[it.key] = it
  end
  width = width + 4

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "curate-transient"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    anchor = "SE",
    row = vim.o.lines - 2,
    col = vim.o.columns - 2,
    width = width,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = " curate ",
  })
  vim.wo[win].cursorline = false

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  for key, it in pairs(keymap) do
    vim.keymap.set("n", key, function()
      if it.arg then
        return -- sticky args are toggled by callers that pass a stateful run
      end
      close()
      if it.run then
        vim.schedule(it.run)
      end
    end, { buffer = buf, nowait = true })
  end
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, close, { buffer = buf, nowait = true })
  end

  return { buf = buf, win = win, close = close }
end

return M
