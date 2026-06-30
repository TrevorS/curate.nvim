-- jj/runner.lua — the only way out of the plugin to the jj binary.
--
-- Argv arrays through vim.system; never a shell. No string concatenation, no
-- quoting bugs, no injection surface. Async callbacks land back on the main
-- loop via vim.schedule_wrap. (§C of the Lua Architecture sketch.)

---@class curate.RunOpts
---@field cwd? string
---@field raw? boolean              keep bytes — templates use \x1f / \x1e
---@field env? table<string,string>
---@field stdin? string

---@class curate.RunResult
---@field code integer
---@field stdout string
---@field stderr string

local M = {}

-- --color=never so we never parse ANSI; --no-pager so jj never blocks on a pager.
local BASE = { "jj", "--no-pager", "--color=never" }

---@param args string[]
---@return string[]
local function argv(args)
  return vim.list_extend(vim.deepcopy(BASE), args)
end

--- Async jj. The whole plugin reaches the binary through here.
---@param args string[]                                   e.g. { "log", "-r", "@" }
---@param opts curate.RunOpts|nil
---@param on_done fun(r: curate.RunResult)|nil
---@return vim.SystemObj
function M.spawn(args, opts, on_done)
  opts = opts or {}
  local system_opts = {
    text = not opts.raw,
    cwd = opts.cwd,
    env = opts.env,
    stdin = opts.stdin,
  }
  return vim.system(
    argv(args),
    system_opts,
    vim.schedule_wrap(function(r) -- back on the main loop
      if r.code ~= 0 then
        -- Surface failures in the process log, but still hand the result back
        -- so callers can branch (e.g. "nothing to absorb" is a soft failure).
        local ok, process = pcall(require, "curate.views.process")
        if ok then
          process.log(args, r)
        end
      end
      if on_done then
        on_done(r)
      end
    end)
  )
end

--- One-shot blocking variant — for setup/health only, never on a keypress.
---@param args string[]
---@param opts curate.RunOpts|nil
---@return curate.RunResult
function M.sync(args, opts)
  opts = opts or {}
  return vim.system(argv(args), { text = not opts.raw, cwd = opts.cwd, env = opts.env }):wait()
end

--- Convenience: async, resolves to stdout string (trimmed) or "" on failure.
---@param args string[]
---@param opts curate.RunOpts|nil
---@param on_text fun(text: string, r: curate.RunResult)
function M.text(args, opts, on_text)
  M.spawn(args, opts, function(r)
    on_text(r.code == 0 and vim.trim(r.stdout or "") or "", r)
  end)
end

return M
