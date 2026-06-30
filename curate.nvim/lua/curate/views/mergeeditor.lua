-- views/mergeeditor.lua — 3-way conflict resolution, the P4 sibling of the
-- diff-editor. jj's ui.merge-editor hands us $base/$left/$right (read-only) and
-- an empty $output to fill. We chunk the file (merge3), auto-apply the
-- non-overlapping changes, and let the user pick a side per real conflict; on
-- <CR> we assemble the resolution into $output and exit 0. Same nvr-style
-- remote-wait handshake as the diff-editor — only the buffer differs.

local render = require("curate.ui.render")
local merge3 = require("curate.diffeditor.merge3")
local fs = require("curate.diffeditor.fs")

local M = {}

-- Cycle order for a conflict's choice (b = base, the "discard both" option, is
-- reachable via its own key rather than the cycle).
local CYCLE = { "left", "right", "left+right", "right+left" }

---@class curate.MergeEditor
---@field base string
---@field left string
---@field right string
---@field output string         the single file to write the resolution into
---@field result string         path the shim polls for the exit code
---@field mode string
---@field name string           display name of the conflicted file
---@field segs curate.MergeSegment[]
---@field buf integer
---@field win integer
---@field ns integer
---@field targets table         row -> segment index (conflict rows only)
local MergeEditor = {}
MergeEditor.__index = MergeEditor

--- Build a MergeEditor over the four merge files.
---@param base string
---@param left string
---@param right string
---@param output string
---@param result string
---@param mode string
---@return curate.MergeEditor
function M.new(base, left, right, output, result, mode)
  local self = setmetatable({
    base = base,
    left = left,
    right = right,
    output = output,
    result = result,
    mode = mode or "merge",
    name = vim.fn.fnamemodify(output, ":t"):gsub("^output_", ""),
    ns = vim.api.nvim_create_namespace("curate.mergeeditor"),
    targets = {},
  }, MergeEditor)
  local b = fs.read(base)
  local l = fs.read(left)
  local r = fs.read(right)
  self.segs = merge3.chunk(b, l, r)
  return self
end

function MergeEditor:open()
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].buftype = "nofile"
  vim.bo[self.buf].bufhidden = "wipe"
  vim.bo[self.buf].filetype = "curate-mergeeditor"
  vim.api.nvim_buf_set_name(self.buf, "curate://mergeeditor/" .. self.name)
  self.win = vim.api.nvim_open_win(self.buf, true, {
    relative = "editor",
    width = math.floor(vim.o.columns * 0.85),
    height = math.floor(vim.o.lines * 0.85),
    row = math.floor(vim.o.lines * 0.07),
    col = math.floor(vim.o.columns * 0.07),
    border = "rounded",
    title = " curate · merge-editor · " .. self.name .. " ",
    style = "minimal",
  })
  vim.wo[self.win].cursorline = true
  self:map()
  self:render()
  M._active = self
end

function MergeEditor:render()
  local rows, targets = {}, {}
  local function push(row, target)
    rows[#rows + 1] = row
    targets[#rows] = target
  end

  local unres, total = merge3.unresolved(self.segs)
  push(render.row():add("MERGE · " .. self.name, "CurateHunkHeader"):done(), nil)
  push(
    render
      .row()
      :add(
        total == 0 and "no real conflicts (auto-merged)"
          or string.format("%d / %d conflicts unresolved", unres, total),
        unres > 0 and "CurateRemoved" or "CurateHint"
      )
      :add(
        "   l left · r right · L l+r · R r+l · b base · <CR> apply · q abort",
        "CurateHint"
      )
      :done(),
    nil
  )
  push(render.row():add("", nil):done(), nil)

  for si, s in ipairs(self.segs) do
    if s.kind == "stable" then
      for _, l in ipairs(s.lines) do
        push(render.row():add("  " .. l, "CurateContext"):done(), nil)
      end
    elseif s.kind == "auto" then
      for _, l in ipairs(s.lines) do
        push(render.row():add("  " .. l, "CurateContext"):done(), nil)
      end
    elseif s.kind == "conflict" then
      local picked = s.choice and ("✓ " .. s.choice) or "● choose a side"
      push(
        render
          .row()
          :add("┌─ conflict  ", "CurateHunkHeader")
          :add(picked, s.choice and "CurateSelected" or "CurateRemoved")
          :done(),
        si
      )
      local function block(label, lines, hl, key)
        push(render.row():add("│ " .. key .. " " .. label, "CurateHint"):done(), si)
        for _, l in ipairs(lines) do
          push(render.row():add("│   " .. l, hl):done(), si)
        end
      end
      block("left", s.left, "CurateAdded", "l")
      block("right", s.right, "CurateRemoved", "r")
      push(render.row():add("└─", "CurateHunkHeader"):done(), si)
    end
  end

  local text = {}
  for i, r in ipairs(rows) do
    text[i] = r[1]
  end
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, text)
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
  for i, r in ipairs(rows) do
    for _, sp in ipairs(r[2] or {}) do
      vim.api.nvim_buf_set_extmark(
        self.buf,
        self.ns,
        i - 1,
        sp[2],
        { end_col = sp[3], hl_group = sp[1] }
      )
    end
  end
  vim.bo[self.buf].modifiable = false
  self.targets = targets
end

---@return curate.MergeSegment|nil
function MergeEditor:seg_at_cursor()
  local row = vim.api.nvim_win_get_cursor(self.win)[1]
  local si = self.targets[row]
  return si and self.segs[si] or nil
end

--- Set the choice on the conflict under the cursor.
---@param choice string
function MergeEditor:choose(choice)
  local s = self:seg_at_cursor()
  if not s or s.kind ~= "conflict" then
    return
  end
  s.choice = choice
  self:render()
end

--- <CR> — assemble and write $output, then exit 0. Blocked while unresolved.
function MergeEditor:confirm()
  local unres = merge3.unresolved(self.segs)
  if unres > 0 then
    vim.notify(
      ("curate: %d conflict(s) still unresolved — pick a side first"):format(unres),
      vim.log.levels.WARN
    )
    return
  end
  local out = merge3.assemble(self.segs)
  fs.write(self.output, out or {})
  self:finish(0)
end

--- q — abort: non-zero so jj leaves the conflict in place.
function MergeEditor:abort()
  self:finish(1)
end

---@param code integer
function MergeEditor:finish(code)
  if self.result then
    local fd = io.open(self.result, "w")
    if fd then
      fd:write(tostring(code))
      fd:close()
    end
  end
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
  end
  if M._active == self then
    M._active = nil
  end
end

--- Move the cursor to the next/prev conflict header.
---@param dir integer 1|-1
function MergeEditor:nav(dir)
  local row = vim.api.nvim_win_get_cursor(self.win)[1]
  local n = vim.api.nvim_buf_line_count(self.buf)
  local i = row + dir
  local last_si = self.targets[row]
  while i >= 1 and i <= n do
    local si = self.targets[i]
    if si and si ~= last_si then
      vim.api.nvim_win_set_cursor(self.win, { i, 0 })
      return
    end
    i = i + dir
  end
end

function MergeEditor:map()
  local function bind(lhs, fn)
    vim.keymap.set("n", lhs, function()
      fn(self)
    end, { buffer = self.buf, nowait = true, silent = true })
  end
  bind("l", function(s)
    s:choose("left")
  end)
  bind("r", function(s)
    s:choose("right")
  end)
  bind("L", function(s)
    s:choose("left+right")
  end)
  bind("R", function(s)
    s:choose("right+left")
  end)
  bind("b", function(s)
    s:choose("base")
  end)
  bind("<CR>", MergeEditor.confirm)
  bind("q", MergeEditor.abort)
  bind("]c", function(s)
    s:nav(1)
  end)
  bind("[c", function(s)
    s:nav(-1)
  end)
end

M.MergeEditor = MergeEditor
M._cycle = CYCLE
return M
