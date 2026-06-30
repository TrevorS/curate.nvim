-- views/annotate.lua — blame. `jj file annotate` line-by-line, shown as a narrow
-- gutter window scroll-bound to the source file: scroll the code, the blame
-- follows. Each line carries the change that introduced it (+ age), so you can
-- jump from a line straight to the change that wrote it.

local jj = require("curate.jj")

local US = "\31" -- \x1f field delimiter (same trick as the log template)
local TEMPLATE = table.concat({
  "commit.change_id().short(8)",
  '"' .. US .. '"',
  "commit.author().timestamp().ago()",
  '"' .. US .. '"',
  "content",
}, " ++ ")

local M = {}

--- Parse `jj file annotate` output (with our delimited template) into per-line
--- blame records. Pure: testable without windows.
---@param stdout string
---@return { id: string, age: string, content: string }[]
function M.parse(stdout)
  local out = {}
  for _, line in ipairs(vim.split(stdout, "\n", { plain = true })) do
    if line ~= "" then
      local id, age, content =
        line:match("^([^" .. US .. "]*)" .. US .. "([^" .. US .. "]*)" .. US .. "(.*)$")
      if id then
        out[#out + 1] = { id = id, age = age, content = content }
      end
    end
  end
  return out
end

--- Build the gutter text (id + age) for each blamed line, padded to align.
---@param records { id: string, age: string }[]
---@return string[]
function M.gutter(records)
  local idw = 0
  for _, r in ipairs(records) do
    idw = math.max(idw, #r.id)
  end
  local lines = {}
  for _, r in ipairs(records) do
    lines[#lines + 1] = string.format("%-" .. idw .. "s  %s", r.id, r.age)
  end
  return lines
end

--- Open a blame gutter for a file, scroll-bound to its source window.
---@param opts { file?: string, rev?: string, win?: integer }|nil
function M.open(opts)
  opts = opts or {}
  local src_win = opts.win or vim.api.nvim_get_current_win()
  local src_buf = vim.api.nvim_win_get_buf(src_win)
  local file = opts.file or vim.api.nvim_buf_get_name(src_buf)
  if file == "" or vim.fn.filereadable(file) == 0 then
    vim.notify("curate: annotate needs a saved file in the current window", vim.log.levels.WARN)
    return
  end
  local rev = opts.rev or "@"

  jj.run({ "file", "annotate", "-r", rev, "-T", TEMPLATE, file }, function(r)
    if r.code ~= 0 then
      vim.notify(
        "curate: annotate: " .. (r.stderr ~= "" and r.stderr or "failed"),
        vim.log.levels.WARN
      )
      return
    end
    local records = M.parse(r.stdout)
    local self = M._render(records, src_win)
    M._active = self
  end)
end

--- Create the gutter buffer/window and scroll-bind it to the source. Split out
--- from open() so it runs on the main loop and is reusable by tests.
---@param records { id: string, age: string }[]
---@param src_win integer
---@return table
function M._render(records, src_win)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "curate-annotate"
  local gutter = M.gutter(records)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, gutter)
  vim.bo[buf].modifiable = false

  -- Width: longest gutter line, clamped.
  local width = 12
  for _, l in ipairs(gutter) do
    width = math.max(width, #l)
  end
  width = math.min(width + 1, 48)

  -- Put the gutter to the left of the source window.
  vim.api.nvim_set_current_win(src_win)
  vim.cmd("leftabove " .. width .. "vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  vim.wo[win].winfixwidth = true

  -- Scroll- and cursor-bind both windows so the blame tracks the code.
  for _, w in ipairs({ win, src_win }) do
    vim.wo[w].scrollbind = true
    vim.wo[w].cursorbind = true
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd("normal! gg")
  vim.cmd("syncbind")

  -- change-id per gutter line, for jump-to-change.
  local ids = {}
  for i, r in ipairs(records) do
    ids[i] = r.id
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      pcall(function()
        vim.wo[src_win].scrollbind = false
        vim.wo[src_win].cursorbind = false
      end)
      vim.api.nvim_win_close(win, true)
    end
    if M._active and M._active.win == win then
      M._active = nil
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<CR>", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local id = ids[row]
    if id then
      require("curate.actions.name").edit_target(id)
    end
  end, { buffer = buf, nowait = true, silent = true })

  return { buf = buf, win = win, src_win = src_win, ids = ids, close = close }
end

return M
