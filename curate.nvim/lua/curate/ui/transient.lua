-- ui/transient.lua — the popup engine (args · sticky · dispatch).
--
-- A minimal magit-style transient: a floating menu of single-key actions that
-- self-documents. Items are either **actions** (`run`) or sticky **args**:
--   • boolean arg — `{arg = true, flag = "--foo"}`; its key toggles it ([ ]/[✓]).
--   • value arg   — `{arg = true, value = true, flag = "--remote"}`; its key
--     prompts for a value ([ ]/[=origin]) and contributes `flag value`.
-- Toggling an arg keeps the buffer open; an action's `run(flags)` receives the
-- enabled flags so it can append them to its argv. Used by the sync / push /
-- rebase / bookmark / power menus.

local M = {}

---@class curate.TransientItem
---@field key string
---@field label string
---@field run fun(flags: string[])|nil   action; receives enabled arg flags
---@field arg boolean|nil                 sticky argument rather than an action
---@field flag string|nil                 the argv flag an `arg` item contributes
---@field value boolean|nil               arg carries a prompted value
---@field on boolean|nil                  current toggle state (boolean args)
---@field val string|nil                  current value (value args)

---@class curate.TransientSpec
---@field title string
---@field items curate.TransientItem[]

---@param spec curate.TransientSpec
---@return { buf: integer, win: integer, close: fun(), flags: fun():string[], toggle: fun(key:string), setval: fun(key:string, val:string|nil) }
function M.open(spec)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "curate-transient"

  -- The enabled arg flags, in item order. A boolean contributes its flag; a
  -- value arg contributes flag + value (two argv entries).
  local function flags()
    local out = {}
    for _, it in ipairs(spec.items) do
      if it.arg and it.flag then
        if it.value then
          if it.val and it.val ~= "" then
            out[#out + 1] = it.flag
            out[#out + 1] = it.val
          end
        elseif it.on then
          out[#out + 1] = it.flag
        end
      end
    end
    return out
  end

  local function state_box(it)
    if it.value then
      return (it.val and it.val ~= "") and ("[=" .. it.val .. "]") or "[ ]"
    end
    return it.on and "[✓]" or "[ ]"
  end

  local function lines()
    local ls = { "  " .. spec.title, "" }
    for _, it in ipairs(spec.items) do
      if it.arg then
        ls[#ls + 1] = string.format("  - %-3s %s %s", it.key, state_box(it), it.label)
      else
        ls[#ls + 1] = string.format("    %-3s %s", it.key, it.label)
      end
    end
    return ls
  end

  local win
  local width = #spec.title
  local function paint()
    local ls = lines()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, ls)
    vim.bo[buf].modifiable = false
    for _, l in ipairs(ls) do
      width = math.max(width, vim.fn.strdisplaywidth(l))
    end
    -- grow the window if a value widened a line
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, { width = width + 4 })
    end
    return ls
  end

  local ls = paint()
  win = vim.api.nvim_open_win(buf, true, {
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

  -- Flip a boolean arg and repaint (the window stays open).
  local function toggle(key)
    for _, it in ipairs(spec.items) do
      if it.key == key and it.arg and not it.value then
        it.on = not it.on
      end
    end
    paint()
  end

  -- Set (or clear, with nil/empty) a value arg and repaint.
  local function setval(key, val)
    for _, it in ipairs(spec.items) do
      if it.key == key and it.arg and it.value then
        it.val = (val and val ~= "") and val or nil
      end
    end
    paint()
  end

  for _, it in ipairs(spec.items) do
    vim.keymap.set("n", it.key, function()
      if it.arg and it.value then
        vim.ui.input({ prompt = it.label .. " = ", default = it.val or "" }, function(input)
          if input ~= nil then -- nil = cancelled; keep current value
            setval(it.key, input)
          end
        end)
      elseif it.arg then
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

  return { buf = buf, win = win, close = close, flags = flags, toggle = toggle, setval = setval }
end

return M
