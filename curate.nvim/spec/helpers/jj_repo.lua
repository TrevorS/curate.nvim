-- Test helper: create and drive a throwaway jj repo inside the nvim runtime.
-- Integration specs use this so they exercise the real jj binary.

-- Pin the plugin's lua dir on package.path ABSOLUTELY, while cwd is still the
-- plugin root (specs chdir into temp repos, which would otherwise break the
-- relative `lua/?.lua` entry busted sets up).
do
  local root = vim.uv.cwd()
  local abs = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. root .. "/?.lua"
  if not package.path:find(root, 1, true) then
    package.path = abs .. ";" .. package.path
  end
  -- Put the plugin on the runtimepath so nvim_get_runtime_file finds bin/, etc.
  vim.opt.runtimepath:prepend(root)
end

local H = {}

--- Make a temp dir, init a jj repo, set identity. Returns its path.
--- Sets HOME inside the repo so jj user config never escapes the sandbox.
---@return string dir
function H.make()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local home = dir .. "/.home"
  vim.fn.mkdir(home, "p")
  H._home = home
  H._env = { HOME = home }
  local function run(args)
    return vim
      .system(vim.list_extend({ "jj", "--no-pager", "--color=never" }, args), {
        cwd = dir,
        env = H._env,
        text = true,
      })
      :wait()
  end
  run({ "git", "init", "." })
  run({ "config", "set", "--user", "user.name", "Spec" })
  run({ "config", "set", "--user", "user.email", "spec@curate.nvim" })
  H._run = function(args)
    return run(args)
  end
  return dir
end

--- Run a jj command in the test repo (after make()).
---@param dir string
---@param args string[]
---@return vim.SystemCompleted
function H.jj(dir, args)
  return vim
    .system(vim.list_extend({ "jj", "--no-pager", "--color=never" }, args), {
      cwd = dir,
      env = H._env,
      text = true,
    })
    :wait()
end

--- Write a file in the repo.
function H.write(dir, rel, contents)
  local path = dir .. "/" .. rel
  local f = assert(io.open(path, "w"))
  f:write(contents)
  f:close()
end

--- Whether jj is available at all (skip integration specs otherwise).
---@return boolean
function H.has_jj()
  return vim.fn.executable("jj") == 1
end

H.env = function()
  return H._env
end

return H
