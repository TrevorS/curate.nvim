-- ui/render.lua — content highlight the modern way.
--
-- Views build `{text, spans}` rows; we flush them in one pass: set all lines,
-- clear the namespace, then lay extmark highlights. No matchadd, no syntax
-- regions. (§F of the Lua Architecture sketch.)

local M = {}

---@alias curate.Span { [1]:string, [2]:integer, [3]:integer }  hl_group, start_col, end_col
---@class curate.Row
---@field [1] string          text
---@field [2]? curate.Span[]  highlights
---@field [3]? string         line background hl_group (whole row, incl. EOL)

--- A tiny builder so views compose a row left-to-right without counting columns.
---@class curate.RowBuilder
---@field text string
---@field spans curate.Span[]
---@field line_hl string|nil
local Builder = {}
Builder.__index = Builder

---@return curate.RowBuilder
function M.row()
  return setmetatable({ text = "", spans = {} }, Builder)
end

--- Append a chunk, optionally highlighted with `hl`.
---@param s string
---@param hl string|nil
---@return curate.RowBuilder
function Builder:add(s, hl)
  s = s or ""
  if hl and #s > 0 then
    local start_col = #self.text
    self.spans[#self.spans + 1] = { hl, start_col, start_col + #s }
  end
  self.text = self.text .. s
  return self
end

--- Append a chunk carrying pre-computed highlight spans (byte cols relative to
--- the chunk), e.g. treesitter output from ui/syntax. Spans are re-based onto
--- the row's current column so callers never count columns themselves.
---@param s string
---@param spans curate.Span[]|nil
---@return curate.RowBuilder
function Builder:add_spans(s, spans)
  s = s or ""
  local base = #self.text
  for _, sp in ipairs(spans or {}) do
    self.spans[#self.spans + 1] = { sp[1], base + sp[2], base + sp[3] }
  end
  self.text = self.text .. s
  return self
end

--- Tint the whole row (including past EOL) with a background hl_group. Used for
--- diff add/remove lines so foreground syntax spans stay legible on top.
---@param hl string|nil
---@return curate.RowBuilder
function Builder:line_bg(hl)
  self.line_hl = hl
  return self
end

--- Add a highlight over already-appended text, by absolute byte columns, without
--- appending any text. Laid after earlier spans, so a background emphasis (e.g.
--- word-diff) overrides an earlier line tint while foreground spans survive.
---@param start_col integer
---@param end_col integer
---@param hl string|nil
---@return curate.RowBuilder
function Builder:mark(start_col, end_col, hl)
  if hl and end_col > start_col then
    self.spans[#self.spans + 1] = { hl, start_col, end_col }
  end
  return self
end

--- Materialise into a `curate.Row`.
---@return curate.Row
function Builder:done()
  return { self.text, self.spans, self.line_hl }
end

--- Flush rows into a view's buffer + namespace in one pass.
---@param v curate.View
---@param rows curate.Row[]
function M.flush(v, rows)
  if not v:valid() then
    return
  end
  local text = {}
  for i, r in ipairs(rows) do
    text[i] = r[1]
  end
  vim.bo[v.buf].modifiable = true
  vim.api.nvim_buf_set_lines(v.buf, 0, -1, false, text)
  vim.api.nvim_buf_clear_namespace(v.buf, v.ns, 0, -1)
  for i, r in ipairs(rows) do
    if r[3] then
      -- Line background first (low, implicit priority) so per-cell foreground
      -- spans render on top; bg + fg merge per attribute.
      vim.api.nvim_buf_set_extmark(v.buf, v.ns, i - 1, 0, {
        line_hl_group = r[3],
        hl_eol = true,
      })
    end
    for _, s in ipairs(r[2] or {}) do
      vim.api.nvim_buf_set_extmark(v.buf, v.ns, i - 1, s[2], {
        end_col = s[3],
        hl_group = s[1],
      })
    end
  end
  vim.bo[v.buf].modifiable = false
end

return M
