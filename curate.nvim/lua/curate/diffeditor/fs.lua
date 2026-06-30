-- diffeditor/fs.lua — read/write/enumerate the $left and $right trees jj hands
-- the diff editor. Thin wrappers so the view stays focused on UI.

local M = {}

local IGNORE = { ["JJ-INSTRUCTIONS"] = true }

--- Relative paths of regular files under `dir` (recursive), minus jj metadata.
---@param dir string
---@return string[]
function M.list(dir)
  local out = {}
  if vim.fn.isdirectory(dir) == 0 then
    return out
  end
  for name, type in vim.fs.dir(dir, { depth = 32 }) do
    if type == "file" and not IGNORE[name] then
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

--- Read a file as a list of lines ({} if missing). Second return: is_binary.
---@param path string
---@return string[] lines, boolean is_binary
function M.read(path)
  local fd = io.open(path, "rb")
  if not fd then
    return {}, false
  end
  local data = fd:read("*a") or ""
  fd:close()
  local is_binary = data:find("\0", 1, true) ~= nil
  if is_binary then
    return { "<binary>" }, true
  end
  -- Split on \n; drop a single trailing empty produced by a final newline.
  local lines = vim.split(data, "\n", { plain = true })
  if #lines > 0 and lines[#lines] == "" then
    lines[#lines] = nil
  end
  return lines, false
end

--- Write lines back to a file (joined with \n, trailing newline).
---@param path string
---@param lines string[]
function M.write(path, lines)
  local fd = assert(io.open(path, "wb"))
  if #lines > 0 then
    fd:write(table.concat(lines, "\n"))
    fd:write("\n")
  end
  fd:close()
end

--- Remove a file if it exists (used when an added file is fully deselected).
---@param path string
function M.remove(path)
  os.remove(path)
end

function M.exists(path)
  return vim.fn.filereadable(path) == 1
end

return M
