-- views/file.lua — curate://<change_id>/<path> buffers: edit any revision's
-- file. Buffers named by change-id survive rewrites and bookmark moves. Read
-- pulls the file at the revision; write commits it back with the cp-as-merge-
-- tool trick (no temp git repo). (§H of the architecture; NicolasGB's plumbing,
-- generalised.)

local jj = require("curate.jj")

local M = {}

--- Parse curate://CHANGE/PATH -> change, path.
---@param url string
---@return string change, string path
local function parse_url(url)
  local rest = url:gsub("^curate://", "")
  local change, path = rest:match("^([^/]+)/(.+)$")
  return change, path
end

--- BufReadCmd: load the file's content at the revision.
---@param buf integer
---@param url string
function M.read(buf, url)
  local change, path = parse_url(url)
  if not change then
    return
  end
  jj.run({ "file", "show", "-r", change, path }, function(r)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local body = r.code == 0 and r.stdout or ""
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(body, "\n", { plain = true }))
    -- adopt the real file's filetype for syntax highlighting
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].modified = false
    local ft = vim.filetype.match({ filename = path, buf = buf })
    if ft then
      vim.bo[buf].filetype = ft
    end
  end)
end

--- BufWriteCmd: commit the buffer back into the revision via cp-as-merge-tool.
---@param buf integer
---@param url string
function M.write(buf, url)
  local change, path = parse_url(url)
  if not change then
    return
  end
  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), tmp)
  jj.run({
    "diffedit",
    "--restore-descendants",
    "-r",
    change,
    "--config",
    "merge-tools.curate-write.program=cp",
    "--config",
    ('merge-tools.curate-write.edit-args=["%s","$right/%s"]'):format(tmp, path),
    "--tool",
    "curate-write",
  }, function(r)
    if r.code == 0 then
      if vim.api.nvim_buf_is_valid(buf) then
        vim.bo[buf].modified = false
      end
      local View = require("curate.ui.view")
      for _, kind in ipairs({ "status", "log" }) do
        local v = View.get(kind)
        if v then
          v:refresh()
        end
      end
    else
      vim.notify("curate: write failed: " .. (r.stderr or ""), vim.log.levels.ERROR)
    end
    os.remove(tmp)
  end)
end

--- :Curate edit <change>:<path> — open a curate:// buffer.
---@param change string
---@param path string
function M.edit(change, path)
  vim.cmd.edit("curate://" .. change .. "/" .. path)
end

return M
