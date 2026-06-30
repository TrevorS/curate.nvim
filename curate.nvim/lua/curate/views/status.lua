-- views/status.lua — the home. @ and its description, the working-copy diff as
-- a foldable files->hunks tree, then a short log graph from the configured
-- revset. Every line maps to an action target (change / file / hunk).

local View = require("curate.ui.view")
local render = require("curate.ui.render")
local tree = require("curate.ui.tree")
local decor = require("curate.ui.decor")
local jj = require("curate.jj")
local config = require("curate.config")
local model = require("curate.jj.model")

local Status = setmetatable({}, { __index = View })
Status.__index = Status

---@return Status
function Status.new()
  local self = View.new("status")
  self.changes = {} ---@type curate.Change[]
  self.files = {} ---@type curate.DiffFile[]
  self.tree = tree.new({})
  self.targets = {} ---@type table<integer, table>  1-based row -> target
  return setmetatable(self, Status)
end

--- Public entry: open (or focus) the home and load it.
function Status.open()
  local existing = View.get("status")
  if existing then
    vim.api.nvim_set_current_win(existing.win)
    existing:reload()
    return existing
  end
  local self = Status.new()
  View.open(self)
  self:reload()
  return self
end

--- Re-fetch everything, then paint. Coalesced via View:refresh debounce when
--- called rapidly after mutations.
function Status:reload()
  jj.working_diff(function(files)
    self.tree = tree.new(files, self.tree)
    self.files = files
    jj.log(config.options.log_revset, function(changes)
      self.changes = changes
      if self:valid() then
        self:render()
      end
    end)
  end)
end

-- The status home reloads (re-queries jj) on refresh, not just re-renders.
function Status:refresh()
  if self._t then
    self._t:stop()
  end
  self._t = vim.defer_fn(function()
    if self:valid() then
      self:reload()
    end
  end, config.options.refresh_debounce or 80)
end

---@return curate.Change|nil
function Status:current_change()
  for _, c in ipairs(self.changes) do
    if c.flags.current then
      return c
    end
  end
  return self.changes[1]
end

function Status:render()
  local rows = {}
  local targets = {}
  local row2id = {}

  local function push(row, target)
    rows[#rows + 1] = row
    targets[#rows] = target
  end

  -- ── header: @ and its description ──
  local cur = self:current_change()
  if cur then
    local h = render.row():add("@ ", "CurateCurrent"):add(model.short(cur), "CurateChangeId")
    if cur.subject == "" then
      h:add("  (no description set)", "CurateHint")
    else
      h:add("  " .. cur.subject, "CurateSubject")
    end
    push(h:done(), { type = "change", id = cur.id, change = cur })
    row2id[#rows - 1] = cur.id
    push(render.row():add("", nil):done(), nil)
  end

  -- ── working-copy diff tree ──
  if #self.files == 0 then
    push(render.row():add("  working copy clean", "CurateHint"):done(), nil)
  else
    push(render.row():add("Working copy changes", "CurateFile"):done(), nil)
    for _, node in ipairs(self.tree:nodes()) do
      if node.kind == "file" then
        local fold = node.folded and "▸" or "▾"
        local f = node.file
        local r = render
          .row()
          :add("  " .. fold .. " ", "CurateGraph")
          :add(f.status .. " ", "CurateHunkHeader")
          :add(f.path, "CurateFile")
          :add(string.format("  +%d", f.added), "CurateAdded")
          :add(string.format(" -%d", f.removed), "CurateRemoved")
        push(r:done(), { type = "file", file = f })
      else
        local r = render.row():add("      ", nil):add(node.hunk.header, "CurateHunkHeader")
        push(r:done(), { type = "hunk", file = node.file, hunk = node.hunk })
      end
    end
  end

  -- ── log graph ──
  push(render.row():add("", nil):done(), nil)
  push(render.row():add("Log", "CurateFile"):done(), nil)
  for _, c in ipairs(self.changes) do
    local glyph = model.glyph(c)
    local idhl = c.flags.current and "CurateCurrent"
      or (c.flags.immutable and "CurateImmutable" or "CurateChangeId")
    local r = render.row():add("  " .. glyph .. " ", "CurateGraph"):add(model.short(c), idhl)
    if c.flags.conflict then
      r:add(" ✗", "CurateConflict")
    end
    if c.flags.divergent then
      r:add(" ??", "CurateDivergent")
    end
    local subj = c.subject ~= "" and c.subject or "(no description set)"
    r:add("  " .. subj, c.subject ~= "" and "CurateSubject" or "CurateHint")
    r:add("  " .. c.ago, "CurateAgo")
    push(r:done(), { type = "change", id = c.id, change = c })
    row2id[#rows - 1] = c.id
  end

  render.flush(self, rows)
  self.targets = targets
  decor.bind(self.buf, row2id)
end

--- The action target under the cursor.
---@return table|nil
function Status:target()
  return self.targets[self:cursor_row() + 1]
end

--- Toggle the fold of the file under the cursor (Tab).
function Status:toggle_fold()
  local t = self:target()
  if t and (t.type == "file" or t.type == "hunk") then
    self.tree:toggle(t.file.path)
    self:render()
  end
end

return Status
