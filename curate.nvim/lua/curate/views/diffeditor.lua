-- views/diffeditor.lua — the hunk-selection buffer. ONE buffer, four modes
-- (split / squash-i / diffedit / restore); only the statusline label changes.
--
-- jj hands us $left (before) and $right (after, writable). Every hunk starts
-- SELECTED (= included in $right). On <CR> we reconstruct each $right file from
-- only the selected hunks and signal exit 0; on q we signal non-zero and jj
-- cancels. (§3 of the spec, §G of the architecture.)

local render = require("curate.ui.render")
local syntax = require("curate.ui.syntax")
local config = require("curate.config")
local hunks_engine = require("curate.diffeditor.hunks")
local fs = require("curate.diffeditor.fs")

--- Build one diff-content row: a colored +/- gutter, then the code either
--- syntax-highlighted with an add/remove line tint, or flat-colored as a
--- fallback (no treesitter parser, or the feature disabled).
---@param gutter string     e.g. "    + "
---@param code string
---@param lang string|nil
---@param sign_hl string    fg group for the gutter sign (CurateAdded/CurateRemoved)
---@param line_hl string    bg group for the whole row (CurateAddedLine/…)
---@return curate.Row
local function diff_row(gutter, code, lang, sign_hl, line_hl)
  local r = render.row():add(gutter, sign_hl)
  local spans = lang and syntax.spans(code, lang) or {}
  if #spans > 0 then
    r:add_spans(code, spans):line_bg(line_hl)
  else
    r:add(code, sign_hl) -- no parser: keep the flat green/red line
  end
  return r:done()
end

local M = {}

local MODE_LABEL = {
  split = "SPLIT · selection = first change",
  ["squash-i"] = "SQUASH-i · selection moves into target",
  diffedit = "DIFFEDIT · selection = new content of @",
  restore = "RESTORE · selection = reverted from parent",
}

---@class curate.DiffEditor
---@field left string
---@field right string
---@field mode string
---@field result string         path the shim polls for the exit code
---@field files table[]         { path, old, new, added, deleted, binary, hunks, selected }
---@field buf integer
---@field win integer
---@field ns integer
---@field targets table         row -> { file_index, hunk_index|nil }
local DiffEditor = {}
DiffEditor.__index = DiffEditor

--- Build a DiffEditor over the two trees.
---@param left string
---@param right string
---@param mode string
---@param result string
---@return curate.DiffEditor
function M.new(left, right, mode, result)
  local self = setmetatable({
    left = left,
    right = right,
    mode = mode or "split",
    result = result,
    files = {},
    ns = vim.api.nvim_create_namespace("curate.diffeditor"),
    targets = {},
  }, DiffEditor)
  self:scan()
  return self
end

--- Enumerate changed files and compute their hunks.
function DiffEditor:scan()
  local seen, names = {}, {}
  for _, p in ipairs(fs.list(self.right)) do
    if not seen[p] then
      seen[p] = true
      names[#names + 1] = p
    end
  end
  for _, p in ipairs(fs.list(self.left)) do
    if not seen[p] then
      seen[p] = true
      names[#names + 1] = p
    end
  end
  table.sort(names)

  self.files = {}
  for _, p in ipairs(names) do
    local old, ob = fs.read(self.left .. "/" .. p)
    local new, nb = fs.read(self.right .. "/" .. p)
    local added = not fs.exists(self.left .. "/" .. p)
    local deleted = not fs.exists(self.right .. "/" .. p)
    local binary = ob or nb
    local h = binary and {} or hunks_engine.compute(old, new)
    local selected = {}
    for i = 1, #h do
      selected[i] = true
    end
    self.files[#self.files + 1] = {
      path = p,
      old = old,
      new = new,
      added = added,
      deleted = deleted,
      binary = binary,
      hunks = h,
      selected = selected,
      file_selected = true, -- for binary / whole-file toggle
    }
  end
end

function DiffEditor:open()
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].buftype = "nofile"
  vim.bo[self.buf].bufhidden = "wipe"
  vim.bo[self.buf].filetype = "curate-diffeditor"
  vim.api.nvim_buf_set_name(self.buf, "curate://diffeditor/" .. self.mode)
  self.win = vim.api.nvim_open_win(self.buf, true, {
    relative = "editor",
    width = math.floor(vim.o.columns * 0.85),
    height = math.floor(vim.o.lines * 0.85),
    row = math.floor(vim.o.lines * 0.07),
    col = math.floor(vim.o.columns * 0.07),
    border = "rounded",
    title = " curate · diff-editor · " .. self.mode:upper() .. " ",
    style = "minimal",
  })
  vim.wo[self.win].cursorline = true
  self:map()
  self:render()
  M._active = self -- handle for tests / single active editor invariant
end

function DiffEditor:counts()
  local total, sel = 0, 0
  for _, f in ipairs(self.files) do
    if f.binary then
      total = total + 1
      sel = sel + (f.file_selected and 1 or 0)
    else
      for i = 1, #f.hunks do
        total = total + 1
        sel = sel + (f.selected[i] and 1 or 0)
      end
    end
  end
  return sel, total
end

function DiffEditor:render()
  local rows, targets = {}, {}
  local function push(row, target)
    rows[#rows + 1] = row
    targets[#rows] = target
  end

  local sel, total = self:counts()
  push(render.row():add(MODE_LABEL[self.mode] or self.mode, "CurateHunkHeader"):done(), nil)
  push(
    render
      .row()
      :add(string.format("%d / %d hunks selected", sel, total), "CurateHint")
      :add("   <space> toggle · a file · A all · <CR> confirm · q abort", "CurateHint")
      :done(),
    nil
  )
  push(render.row():add("", nil):done(), nil)

  for fi, f in ipairs(self.files) do
    local tag = f.added and "A" or (f.deleted and "D" or "M")
    local fr = render
      .row()
      :add(f.file_selected_mark and "" or "", nil)
      :add(tag .. " ", "CurateHunkHeader")
      :add(f.path, "CurateFile")
    if f.binary then
      local mark = f.file_selected and "[x]" or "[ ]"
      fr:add("  " .. mark .. " binary (file-level)", "CurateHint")
    end
    push(fr:done(), { file_index = fi })

    if not f.binary then
      local lang = config.get("diff_syntax") and syntax.lang_for(f.path) or nil
      for hi, h in ipairs(f.hunks) do
        local mark = f.selected[hi] and "[x]" or "[ ]"
        local hl = f.selected[hi] and "CurateSelected" or "CurateDeselected"
        push(
          render
            .row()
            :add("  " .. mark .. " ", hl)
            :add(
              string.format("@@ -%d,%d +%d @@", h.old_start, h.old_count, #h.new_lines),
              "CurateHunkHeader"
            )
            :done(),
          { file_index = fi, hunk_index = hi }
        )
        for _, l in ipairs(h.old_lines) do
          push(
            diff_row("    - ", l, lang, "CurateRemoved", "CurateRemovedLine"),
            { file_index = fi, hunk_index = hi }
          )
        end
        for _, l in ipairs(h.new_lines) do
          push(
            diff_row("    + ", l, lang, "CurateAdded", "CurateAddedLine"),
            { file_index = fi, hunk_index = hi }
          )
        end
      end
    end
    push(render.row():add("", nil):done(), nil)
  end

  -- flush
  local text = {}
  for i, r in ipairs(rows) do
    text[i] = r[1]
  end
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, text)
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
  for i, r in ipairs(rows) do
    if r[3] then
      -- Whole-row add/remove tint underneath the foreground syntax spans.
      vim.api.nvim_buf_set_extmark(self.buf, self.ns, i - 1, 0, {
        line_hl_group = r[3],
        hl_eol = true,
      })
    end
    for _, s in ipairs(r[2] or {}) do
      vim.api.nvim_buf_set_extmark(
        self.buf,
        self.ns,
        i - 1,
        s[2],
        { end_col = s[3], hl_group = s[1] }
      )
    end
  end
  vim.bo[self.buf].modifiable = false
  self.targets = targets
end

function DiffEditor:target()
  local row = vim.api.nvim_win_get_cursor(self.win)[1]
  return self.targets[row]
end

--- <space> — toggle the hunk under the cursor.
function DiffEditor:toggle_hunk()
  local t = self:target()
  if not t then
    return
  end
  local f = self.files[t.file_index]
  if f.binary then
    f.file_selected = not f.file_selected
  elseif t.hunk_index then
    f.selected[t.hunk_index] = not f.selected[t.hunk_index]
  else
    -- on a file header: toggle whole file
    self:toggle_file()
    return
  end
  self:render()
end

--- a — toggle every hunk in the file under the cursor.
function DiffEditor:toggle_file()
  local t = self:target()
  if not t then
    return
  end
  local f = self.files[t.file_index]
  if f.binary then
    f.file_selected = not f.file_selected
  else
    -- if any selected, deselect all; else select all
    local any = false
    for i = 1, #f.hunks do
      any = any or f.selected[i]
    end
    for i = 1, #f.hunks do
      f.selected[i] = not any
    end
  end
  self:render()
end

--- A — toggle all hunks in every file.
function DiffEditor:toggle_all()
  local sel = self:counts()
  local target = sel == 0 -- if nothing selected, select all; else clear all
  for _, f in ipairs(self.files) do
    f.file_selected = target
    for i = 1, #f.hunks do
      f.selected[i] = target
    end
  end
  self:render()
end

--- <CR> — write the selected content back into $right and exit 0.
function DiffEditor:confirm()
  -- Edge case: nothing selected → abort cleanly so jj makes no empty change.
  local sel = self:counts()
  if sel == 0 then
    vim.notify("curate: nothing selected — aborting (no empty change)", vim.log.levels.INFO)
    return self:finish(1)
  end
  for _, f in ipairs(self.files) do
    local rpath = self.right .. "/" .. f.path
    if f.binary then
      if not f.file_selected then
        -- revert: copy $left content back (or remove if it was added)
        if f.added then
          fs.remove(rpath)
        else
          local raw = io.open(self.left .. "/" .. f.path, "rb")
          if raw then
            local data = raw:read("*a")
            raw:close()
            local w = io.open(rpath, "wb")
            if w then
              w:write(data or "")
              w:close()
            end
          end
        end
      end
    else
      local out = hunks_engine.apply(f.old, f.hunks, f.selected)
      -- An added file with nothing selected disappears from $right.
      if f.added and #out == 0 then
        fs.remove(rpath)
      else
        fs.write(rpath, out)
      end
    end
  end
  self:finish(0)
end

--- q — abort: signal non-zero so jj cancels cleanly.
function DiffEditor:abort()
  self:finish(1)
end

--- Write the exit code to the result file the shim is polling, then close.
---@param code integer
function DiffEditor:finish(code)
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

function DiffEditor:map()
  local function bind(lhs, fn)
    vim.keymap.set("n", lhs, function()
      fn(self)
    end, { buffer = self.buf, nowait = true, silent = true })
  end
  bind("<space>", DiffEditor.toggle_hunk)
  bind("a", DiffEditor.toggle_file)
  bind("A", DiffEditor.toggle_all)
  bind("<CR>", DiffEditor.confirm)
  bind("q", DiffEditor.abort)
  -- hunk navigation: jump between hunk-header lines
  bind("]c", function(s)
    s:nav(1)
  end)
  bind("[c", function(s)
    s:nav(-1)
  end)
end

--- Move cursor to the next/prev hunk header.
---@param dir integer 1|-1
function DiffEditor:nav(dir)
  local row = vim.api.nvim_win_get_cursor(self.win)[1]
  local n = vim.api.nvim_buf_line_count(self.buf)
  local i = row + dir
  while i >= 1 and i <= n do
    local t = self.targets[i]
    if t and t.hunk_index then
      vim.api.nvim_win_set_cursor(self.win, { i, 0 })
      return
    end
    i = i + dir
  end
end

M.DiffEditor = DiffEditor
return M
