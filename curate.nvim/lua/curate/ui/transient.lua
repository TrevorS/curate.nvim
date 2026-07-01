-- ui/transient.lua — the popup engine (args · sticky · dispatch).
--
-- A minimal magit-style transient: a floating menu of single-key actions that
-- self-documents. Items are either **actions** (`run`) or sticky **args**
-- (`arg = true, flag = "--foo"`): pressing an arg key toggles it in place
-- ([ ]/[✓]) and the buffer stays open; an action's `run(flags)` receives the
-- list of enabled flags so it can append them to its argv. Used by the sync /
-- push / bookmark / power menus.

local M = {}

---@class curate.TransientItem
---@field key string
---@field label string
---@field run fun(flags: string[])|nil   action; receives enabled arg flags
---@field arg boolean|nil                 sticky toggle argument rather than an action
---@field flag string|nil                 the argv flag an `arg` item contributes
---@field on boolean|nil                  current toggle state (arg items)

---@class curate.TransientSpec
---@field title string
---@field items curate.TransientItem[]

---@param spec curate.TransientSpec
---@return { buf: integer, win: integer, close: fun(), flags: fun():string[], toggle: fun(key:string) }
function M.open(spec)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "curate-transient"

  -- The enabled arg flags, in item order.
  local function flags()
    local out = {}
    for _, it in ipairs(spec.items) do
      if it.arg and it.on and it.flag then
        out[#out + 1] = it.flag
      end
    end
    return out
  end

  local function lines()
    local ls = { "  " .. spec.title, "" }
    for _, it in ipairs(spec.items) do
      if it.arg then
        ls[#ls + 1] = string.format("  - %-3s %s %s", it.key, it.on and "[✓]" or "[ ]", it.label)
      else
        ls[#ls + 1] = string.format("    %-3s %s", it.key, it.label)
      end
    end
    return ls
  end

  local width = #spec.title
  local function paint()
    local ls = lines()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, ls)
    vim.bo[buf].modifiable = false
    for _, l in ipairs(ls) do
      width = math.max(width, vim.fn.strdisplaywidth(l))
    end
    return ls
  end

  local ls = paint()
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    anchor = "SE",
    row = vim.o.lines - 2,
    col = vim.o.columns - 2,
    width = width + 4,
    height = #ls,
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

  -- Flip an arg item and repaint (the window stays open).
  local function toggle(key)
    for _, it in ipairs(spec.items) do
      if it.key == key and it.arg then
        it.on = not it.on
      end
    end
    paint()
  end

  for _, it in ipairs(spec.items) do
    vim.keymap.set("n", it.key, function()
      if it.arg then
        toggle(it.key)
      else
        close()
        if it.run then
          local f = flags()
          vim.schedule(function()
            it.run(f)
          end)
        end
      end
    end, { buffer = buf, nowait = true })
  end
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, close, { buffer = buf, nowait = true })
  end

  return { buf = buf, win = win, close = close, flags = flags, toggle = toggle }
end

return M
