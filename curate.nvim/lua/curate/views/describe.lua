-- views/describe.lua — the message buffer for `jj describe`.
--
-- A real, writable scratch buffer pre-filled with the change's current
-- description. `:w` (BufWriteCmd) applies it via `jj describe`; `q` cancels.
-- Editable on @ anytime — there is no "final" commit in jj.

local jj = require("curate.jj")

local M = {}

local seq = 0

--- Open a describe buffer for a change.
---@param change_id string
---@param opts { after_new?: boolean }|nil   after_new = run `jj new` on save (commit)
function M.open(change_id, opts)
  opts = opts or {}
  -- Fetch the current description to pre-fill.
  jj.run({ "log", "--no-graph", "-r", change_id, "-T", "description" }, function(r)
    local body = r.code == 0 and r.stdout or ""
    seq = seq + 1
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "curate://describe/" .. change_id .. "#" .. seq)
    local lines = vim.split(body, "\n", { plain = true })
    -- jj's `description` ends without a trailing newline-as-empty; trim trailing blanks.
    while #lines > 1 and lines[#lines] == "" do
      lines[#lines] = nil
    end
    vim.list_extend(lines, {
      "",
      "JJ: Describe change " .. change_id:sub(1, 8) .. ". Lines starting with 'JJ:' are dropped.",
      "JJ: :w applies the message"
        .. (opts.after_new and " and starts a new change" or "")
        .. ", :q cancels.",
    })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "gitcommit" -- borrow commit-message highlighting
    vim.bo[buf].modified = false

    vim.api.nvim_open_win(buf, true, { split = "below", height = 12 })

    local function message()
      local raw = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local kept = vim.tbl_filter(function(l)
        return l:sub(1, 3) ~= "JJ:"
      end, raw)
      return vim.trim(table.concat(kept, "\n"))
    end

    local grp = vim.api.nvim_create_augroup("curate.describe." .. seq, {})
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      group = grp,
      buffer = buf,
      callback = function()
        local msg = message()
        jj.run({ "describe", "-r", change_id, "-m", msg }, function(res)
          if res.code == 0 then
            vim.bo[buf].modified = false
            if opts.after_new then
              jj.run({ "new" }, function()
                M._notify_home()
                M._close(buf)
              end)
            else
              M._notify_home()
              M._close(buf)
            end
          else
            vim.notify("curate: describe failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
          end
        end)
      end,
    })
    -- q cancels.
    vim.keymap.set("n", "q", function()
      M._close(buf)
    end, { buffer = buf, nowait = true })
  end)
end

function M._close(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
      pcall(vim.api.nvim_win_close, win, true)
    end
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

function M._notify_home()
  local View = require("curate.ui.view")
  for _, kind in ipairs({ "status", "log" }) do
    local v = View.get(kind)
    if v then
      v:refresh()
    end
  end
end

return M
