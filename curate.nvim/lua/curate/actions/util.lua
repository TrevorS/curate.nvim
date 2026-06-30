-- actions/util.lua — shared plumbing for the verbs: refresh open views, find the
-- target under the cursor, confirm before rewriting immutable changes.

local View = require("curate.ui.view")
local config = require("curate.config")

local M = {}

--- Refresh every open curate view (after any mutation).
function M.refresh_all()
  for _, kind in ipairs({ "status", "log", "oplog", "evolog" }) do
    local v = View.get(kind)
    if v then
      v:refresh()
    end
  end
end

--- The action target under the cursor in the active curate view, if any.
---@return table|nil target, curate.View|nil view
function M.cursor_target()
  local buf = vim.api.nvim_get_current_buf()
  for _, kind in ipairs({ "status", "log", "oplog" }) do
    local v = View.get(kind)
    if v and v.buf == buf and v.target then
      return v:target(), v
    end
  end
  return nil
end

--- The change-id under the cursor, or @ as a fallback.
---@return string|nil
function M.cursor_change_id()
  local t = M.cursor_target()
  if t and t.id then
    return t.id
  end
  return nil
end

--- Run `fn(id)` after confirming, if the targeted change is immutable.
---@param target table|nil
---@param verb string
---@param fn fun()
function M.guard_immutable(target, verb, fn)
  local immutable = target and target.change and target.change.flags.immutable
  if immutable and config.options.confirm_immutable then
    vim.ui.select({ "yes", "no" }, {
      prompt = ("%s an immutable change %s?"):format(verb, target.change.id:sub(1, 8)),
    }, function(choice)
      if choice == "yes" then
        fn()
      end
    end)
  else
    fn()
  end
end

--- Standard mutation: run jj args, surface errors, refresh views.
---@param jjmod table   require("curate.jj")
---@param args string[]
---@param ok_msg string|nil
function M.mutate(jjmod, args, ok_msg)
  jjmod.run(args, function(r)
    if r.code ~= 0 then
      vim.notify(
        "curate: " .. (r.stderr ~= "" and r.stderr or table.concat(args, " ")),
        vim.log.levels.WARN
      )
    elseif ok_msg then
      vim.notify("curate: " .. ok_msg, vim.log.levels.INFO)
    end
    M.refresh_all()
  end)
end

return M
