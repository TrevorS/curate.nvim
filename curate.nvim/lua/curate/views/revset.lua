-- views/revset.lua — the revset workbench. Line 1 is an editable jj revset;
-- everything below is the log it matches, recomputed live as you type
-- (debounced). The power-user's "ask the graph a question" surface — the one
-- place curate leans into jj's revset language instead of hiding it.

local render = require("curate.ui.render")
local jj = require("curate.jj")
local config = require("curate.config")
local model = require("curate.jj.model")

local M = {}

---@class curate.Revset
---@field buf integer
---@field win integer
---@field ns integer
---@field changes curate.Change[]
---@field targets table
---@field _t uv.uv_timer_t|nil
local Revset = {}
Revset.__index = Revset

local PROMPT = "revset❯ "

function M.new()
  return setmetatable({
    ns = vim.api.nvim_create_namespace("curate.revset"),
    changes = {},
    targets = {},
  }, Revset)
end

function M.open()
  if M._active and vim.api.nvim_buf_is_valid(M._active.buf) then
    vim.api.nvim_set_current_win(M._active.win)
    return M._active
  end
  local self = M.new()
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].buftype = "nofile"
  vim.bo[self.buf].filetype = "curate-revset"
  vim.api.nvim_buf_set_name(self.buf, "curate://revset")
  self.win = vim.api.nvim_open_win(self.buf, true, { split = "right" })
  vim.wo[self.win].wrap = false
  vim.wo[self.win].number = false
  vim.wo[self.win].cursorline = true

  -- Seed the query line with the configured log revset.
  vim.api.nvim_buf_set_lines(
    self.buf,
    0,
    -1,
    false,
    { PROMPT .. (config.options.log_revset or "@") }
  )
  self:map()
  self:watch()
  self:recompute()
  M._active = self
  -- Land the cursor at the end of the query, ready to edit.
  vim.api.nvim_win_set_cursor(
    self.win,
    { 1, #vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] }
  )
  return self
end

--- The revset currently typed on line 1 (prompt stripped).
---@return string
function Revset:query()
  local line1 = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  return vim.trim((line1:gsub("^" .. vim.pesc(PROMPT), "")))
end

--- Set the query line programmatically (used by tests / presets).
---@param q string
function Revset:set_query(q)
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, 1, false, { PROMPT .. q })
end

--- Run the current query and re-render the results below line 1.
--- Our own render writes buffer lines, which re-fires the on_lines watcher;
--- the last-query guard makes that self-trigger a no-op so we don't busy-loop
--- jj invocations. Pass force=true to re-run an unchanged query on demand.
---@param force boolean|nil
function Revset:recompute(force)
  local q = self:query()
  if not force and q == self._last_query then
    return
  end
  self._last_query = q
  -- Stamp each query; ignore any response that a newer query has superseded, so
  -- fast typing can't let an older jj.log result clobber the current one.
  self._gen = (self._gen or 0) + 1
  local gen = self._gen
  if q == "" then
    self:render_results({})
    return
  end
  jj.log(q, function(changes, err)
    if gen ~= self._gen or not vim.api.nvim_buf_is_valid(self.buf) then
      return
    end
    self.changes = changes
    if err and #changes == 0 then
      self:render_results(nil, err)
    else
      self:render_results(changes)
    end
  end)
end

--- Replace everything below the query line with the rendered results, leaving
--- line 1 (and the cursor) untouched.
---@param changes curate.Change[]|nil
---@param err string|nil
function Revset:render_results(changes, err)
  local rows, targets = {}, {}
  rows[1] = render.row():add(string.rep("─", 40), "CurateHint"):done()
  if err then
    rows[2] = render.row():add("  ✗ " .. vim.trim(err):gsub("\n.*", ""), "CurateConflict"):done()
  elseif not changes or #changes == 0 then
    rows[2] = render.row():add("  (no matches)", "CurateHint"):done()
  else
    for _, c in ipairs(changes) do
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
    end
  end

  -- Flush rows into the buffer at line index 1.. (preserving the query line 0).
  local text = {}
  for i, r in ipairs(rows) do
    text[i] = r[1]
  end
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 1, -1, false, text)
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 1, -1)
  for i, r in ipairs(rows) do
    for _, s in ipairs(r[2] or {}) do
      vim.api.nvim_buf_set_extmark(self.buf, self.ns, i, s[2], { end_col = s[3], hl_group = s[1] })
    end
  end
  -- result row i (1-based, after the separator) lives on buffer line i.
  self.targets = {}
  for line, t in pairs(targets) do
    self.targets[line] = t
  end
end

--- Live recompute: any edit to the buffer schedules a debounced requery.
function Revset:watch()
  vim.api.nvim_buf_attach(self.buf, false, {
    on_lines = function()
      if not vim.api.nvim_buf_is_valid(self.buf) then
        return true -- detach
      end
      if self._t then
        self._t:stop()
      end
      self._t = vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(self.buf) then
          self:recompute()
        end
      end, config.options.refresh_debounce or 120)
    end,
  })
end

---@return table|nil
function Revset:target()
  local row = vim.api.nvim_win_get_cursor(self.win)[1]
  return self.targets[row]
end

function Revset:close()
  if self._t then
    self._t:stop()
  end
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if vim.api.nvim_buf_is_valid(self.buf) then
    pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
  end
  if M._active == self then
    M._active = nil
  end
end

function Revset:map()
  local function bind(lhs, fn)
    vim.keymap.set("n", lhs, function()
      fn(self)
    end, { buffer = self.buf, nowait = true, silent = true })
  end
  -- <CR> on a result jumps to it in the log; on the query line, force a re-run.
  bind("<CR>", function(s)
    local t = s:target()
    if t then
      require("curate.actions.name").edit_target(t.id)
    else
      s:recompute(true)
    end
  end)
  bind("q", Revset.close)
end

M.Revset = Revset
return M
