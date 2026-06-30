-- views/log.lua — the standalone log graph. A focused history browser; the home
-- embeds a short version, this one shows the full configured revset and hosts
-- the rebase/squash destination marking (live highlight via ui/decor).

local View = require("curate.ui.view")
local render = require("curate.ui.render")
local decor = require("curate.ui.decor")
local jj = require("curate.jj")
local config = require("curate.config")
local model = require("curate.jj.model")

local Log = setmetatable({}, { __index = View })
Log.__index = Log

function Log.new()
  local self = View.new("log")
  self.changes = {}
  self.targets = {}
  self.revset = config.options.log_revset
  return setmetatable(self, Log)
end

function Log.open()
  local existing = View.get("log")
  if existing then
    vim.api.nvim_set_current_win(existing.win)
    existing:reload()
    return existing
  end
  local self = Log.new()
  View.open(self)
  self:reload()
  return self
end

function Log:reload()
  jj.log(self.revset, function(changes)
    self.changes = changes
    if self:valid() then
      self:render()
    end
  end)
end

function Log:refresh()
  if self._t then
    self._t:stop()
  end
  self._t = vim.defer_fn(function()
    if self:valid() then
      self:reload()
    end
  end, config.options.refresh_debounce or 80)
end

function Log:render()
  local rows, targets, row2id = {}, {}, {}
  for _, c in ipairs(self.changes) do
    local glyph = model.glyph(c)
    local idhl = c.flags.current and "CurateCurrent"
      or (c.flags.immutable and "CurateImmutable" or "CurateChangeId")
    local r = render.row():add(glyph .. " ", "CurateGraph"):add(model.short(c), idhl)
    if c.flags.conflict then
      r:add(" ✗", "CurateConflict")
    end
    local subj = c.subject ~= "" and c.subject or "(no description set)"
    r:add("  " .. subj, c.subject ~= "" and "CurateSubject" or "CurateHint")
    r:add("   " .. c.ago, "CurateAgo")
    rows[#rows + 1] = r:done()
    targets[#rows] = { type = "change", id = c.id, change = c }
    row2id[#rows - 1] = c.id
  end
  if #rows == 0 then
    rows[1] = render.row():add("  no changes for revset: " .. self.revset, "CurateHint"):done()
  end
  render.flush(self, rows)
  self.targets = targets
  decor.bind(self.buf, row2id)
end

---@return table|nil
function Log:target()
  return self.targets[self:cursor_row() + 1]
end

return Log
