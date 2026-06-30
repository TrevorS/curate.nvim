-- ui/view.lua — the surface lifecycle base.
--
-- Every view is a `nofile` scratch buffer with a per-kind filetype (drives
-- ftplugin keymaps + treesitter) and its own extmark namespace. Subclasses
-- implement only :render(). (§E of the Lua Architecture sketch.)

local config = require("curate.config")

---@class curate.View
---@field kind string
---@field buf integer
---@field win integer
---@field ns integer
---@field _t uv.uv_timer_t|nil
local View = {}
View.__index = View

-- Registry of live singleton views by kind, so `:Curate status` re-focuses an
-- existing buffer instead of stacking duplicates.
local live = {}

---@param kind string
---@return curate.View
function View.new(kind)
  return setmetatable({
    kind = kind,
    ns = vim.api.nvim_create_namespace("curate." .. kind),
  }, View)
end

--- The live singleton for a kind, if any.
---@param kind string
---@return curate.View|nil
function View.get(kind)
  local v = live[kind]
  if v and v:valid() then
    return v
  end
  return nil
end

---@param win_opts vim.api.keyset.win_config|nil
---@return curate.View
function View:open(win_opts)
  -- Reuse a live buffer for this kind if present.
  local existing = live[self.kind]
  if existing and existing:valid() then
    if existing.win and vim.api.nvim_win_is_valid(existing.win) then
      vim.api.nvim_set_current_win(existing.win)
    else
      existing:open(win_opts)
    end
    return existing
  end

  self.buf = vim.api.nvim_create_buf(false, true)
  local b = vim.bo[self.buf]
  b.buftype = "nofile"
  b.bufhidden = "wipe"
  b.swapfile = false
  b.filetype = "curate-" .. self.kind -- -> ftplugin maps + TS highlight
  vim.api.nvim_buf_set_name(self.buf, "curate://" .. self.kind)

  local opts = win_opts or self:default_win()
  self.win = vim.api.nvim_open_win(self.buf, true, opts)
  vim.wo[self.win].cursorline = true
  vim.wo[self.win].wrap = false
  vim.wo[self.win].number = false
  vim.wo[self.win].signcolumn = "no"

  live[self.kind] = self
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = self.buf,
    once = true,
    callback = function()
      if live[self.kind] == self then
        live[self.kind] = nil
      end
    end,
  })

  self:render()
  return self
end

---@return vim.api.keyset.win_config
function View:default_win()
  local w = config.options.window or {}
  if w.split == "float" then
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    return {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      border = "rounded",
    }
  end
  return { split = w.split or "right" }
end

--- Re-render after any action. jj is fast, so re-render the whole buffer:
--- simplicity beats diff-patching; debounce coalesces rapid mutations.
function View:refresh()
  if self._t then
    self._t:stop()
  end
  self._t = vim.defer_fn(function()
    if self:valid() then
      self:render()
    end
  end, config.options.refresh_debounce or 80)
end

---@return boolean
function View:valid()
  return self.buf ~= nil and vim.api.nvim_buf_is_valid(self.buf)
end

--- Replace buffer lines (handles the modifiable dance). Used by :render().
---@param lines string[]
function View:set_lines(lines)
  if not self:valid() then
    return
  end
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false
end

function View:close()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if self:valid() then
    vim.api.nvim_buf_delete(self.buf, { force = true })
  end
  live[self.kind] = nil
end

function View:render()
  error("subclass must implement :render()")
end

--- Current cursor row (0-indexed) — convenience for subclasses.
---@return integer
function View:cursor_row()
  if not (self.win and vim.api.nvim_win_is_valid(self.win)) then
    return 0
  end
  return vim.api.nvim_win_get_cursor(self.win)[1] - 1
end

return View
