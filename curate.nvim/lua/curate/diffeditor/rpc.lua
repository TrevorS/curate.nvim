-- diffeditor/rpc.lua — the server side of the wedge.
--
-- The shim jj spawns invokes `enter_file` on this running nvim (via
-- `nvim --server <addr> --remote-expr`). We open the hunk buffer and return
-- immediately; the real result (exit code) is written to the shim's result
-- file when the user confirms/aborts, which the shim is polling. This is the
-- nvr-style remote-wait pattern: jj blocks on the shim, the shim blocks on us.

local diffeditor = require("curate.views.diffeditor")

local M = {}

--- Entry the shim calls for `jj resolve` (ui.merge-editor). `req_path` is a
--- 6-line file: base, left, right, output, result, mode. Opens the 3-way merge
--- buffer and returns immediately (does not block).
---@param req_path string
---@return string
function M.enter_merge(req_path)
  local ok, lines = pcall(vim.fn.readfile, req_path)
  if not ok or #lines < 5 then
    return "err: bad request"
  end
  local base, left, right, output, result, mode =
    lines[1], lines[2], lines[3], lines[4], lines[5], lines[6] or "merge"

  vim.schedule(function()
    local mergeeditor = require("curate.views.mergeeditor")
    local ed = mergeeditor.new(base, left, right, output, result, mode)
    ed:open()
  end)
  return "ok"
end

--- Entry the shim calls. `req_path` is a 4-line file: left, right, result, mode.
--- Returns "ok" synchronously after opening the buffer (does not block).
---@param req_path string
---@return string
function M.enter_file(req_path)
  local ok, lines = pcall(vim.fn.readfile, req_path)
  if not ok or #lines < 3 then
    return "err: bad request"
  end
  local left, right, result, mode = lines[1], lines[2], lines[3], lines[4] or "split"

  -- Defer the actual UI work onto the main loop so the remote-expr returns fast.
  vim.schedule(function()
    local ed = diffeditor.new(left, right, mode, result)
    if #ed.files == 0 then
      -- Nothing to edit (e.g. only metadata) — confirm trivially.
      ed:finish(0)
      return
    end
    ed:open()
  end)
  return "ok"
end

return M
