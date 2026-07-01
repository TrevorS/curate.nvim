-- views/oplog.lua — the op-log time machine (TRUST).
--
-- Whole-repo, reversible, append-only: restore writes a NEW op, so forward
-- history is never lost. The surface NicolasGB doesn't have (they ship
-- undo/redo only).

local View = require("curate.ui.view")
local render = require("curate.ui.render")
local jj = require("curate.jj")
local config = require("curate.config")

local Oplog = setmetatable({}, { __index = View })
Oplog.__index = Oplog

function Oplog.new()
  local self = View.new("oplog")
  self.ops = {} ---@type curate.Op[]
  self.targets = {}
  self.flags = {} ---@type string[]  display flags (e.g. --limit) from the options menu
  return setmetatable(self, Oplog)
end

function Oplog.open()
  local existing = View.get("oplog")
  if existing then
    vim.api.nvim_set_current_win(existing.win)
    existing:reload()
    return existing
  end
  local self = Oplog.new()
  View.open(self)
  self:reload()
  return self
end

function Oplog:reload()
  jj.oplog(function(ops)
    self.ops = ops
    if self:valid() then
      self:render()
    end
  end, self.flags)
end

--- o — the op-log options menu: a sticky `-n --limit` value arg that re-renders
--- how many operations are shown. The op-log's take on magit-log's display args.
function Oplog:options()
  require("curate.ui.transient").open({
    title = "op-log options",
    items = {
      { key = "n", arg = true, value = true, flag = "--limit", label = "limit (# ops)" },
      {
        key = "a",
        label = "apply",
        run = function(flags)
          self.flags = flags
          self:reload()
        end,
      },
    },
  })
end

function Oplog:refresh()
  if self._t then
    self._t:stop()
  end
  self._t = vim.defer_fn(function()
    if self:valid() then
      self:reload()
    end
  end, config.options.refresh_debounce or 80)
end

function Oplog:render()
  local rows, targets = {}, {}
  rows[1] = render.row():add("Operation log", "CurateFile"):done()
  rows[2] = render
    .row()
    :add(
      "  <CR> restore · = diff · g- g+ walk · u undo · o options · append-only",
      "CurateHint"
    )
    :done()
  rows[3] = render.row():add("", nil):done()
  for _, op in ipairs(self.ops) do
    local dot = op.current and "●" or "◌"
    local hl = op.current and "CurateOpCurrent" or "CurateGraph"
    local r = render
      .row()
      :add("  " .. dot .. " ", hl)
      :add(op.id:sub(1, 8), "CurateOpId")
      :add("  " .. op.ago, "CurateAgo")
      :add("  " .. op.summary, op.current and "CurateOpCurrent" or "CurateSubject")
    rows[#rows + 1] = r:done()
    targets[#rows] = op
  end
  render.flush(self, rows)
  self.targets = targets
end

---@return curate.Op|nil
function Oplog:op_under_cursor()
  return self.targets[self:cursor_row() + 1]
end

--- <CR> — restore the repo to the op under the cursor (append-only, confirmed).
function Oplog:on_enter()
  local op = self:op_under_cursor()
  if not op then
    return
  end
  vim.ui.select({ "yes", "no" }, {
    prompt = ("Restore repo to op %s (%s)? (writes a new op)"):format(op.id:sub(1, 8), op.summary),
  }, function(choice)
    if choice == "yes" then
      require("curate.actions.trust").op_restore(op.id)
    end
  end)
end

--- = — show the diff this op caused in a split.
function Oplog:show_diff()
  local op = self:op_under_cursor()
  if not op then
    return
  end
  jj.run({ "op", "show", op.id, "--color=never" }, function(r)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(r.stdout or "", "\n", { plain = true }))
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "diff"
    vim.api.nvim_open_win(buf, true, { split = "below", height = 18 })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  end)
end

return Oplog
