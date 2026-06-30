-- jj/init.lua — the high-level data API. Views and actions call these instead
-- of touching the runner/template/diff modules directly.

local runner = require("curate.jj.runner")
local template = require("curate.jj.template")
local diff = require("curate.jj.diff")

local M = {}
M.runner = runner
M.template = template
M.diff = diff

--- Repo working directory. jj resolves the workspace from any subdir, so the
--- editor's cwd is the right anchor.
---@return string
function M.cwd()
  return vim.fn.getcwd()
end

---@param args string[]
---@return curate.RunOpts
local function opts()
  return { cwd = M.cwd() }
end

--- Async log query -> Change[].
---@param revset string
---@param cb fun(changes: curate.Change[], err: string|nil)
function M.log(revset, cb)
  runner.spawn(template.log_args(revset), opts(), function(r)
    if r.code ~= 0 then
      cb({}, r.stderr)
    else
      cb(template.parse_log(r.stdout))
    end
  end)
end

--- Working-copy diff (@ vs its parent) -> DiffFile[].
---@param cb fun(files: curate.DiffFile[], err: string|nil)
---@param revset string|nil   defaults to @
function M.working_diff(cb, revset)
  local rev = revset or "@"
  runner.spawn({ "diff", "--git", "-r", rev }, opts(), function(r)
    if r.code ~= 0 then
      cb({}, r.stderr)
    else
      cb(diff.parse(r.stdout))
    end
  end)
end

--- Op-log query -> Op[].
---@param cb fun(ops: curate.Op[], err: string|nil)
function M.oplog(cb)
  runner.spawn(template.oplog_args(), opts(), function(r)
    if r.code ~= 0 then
      cb({}, r.stderr)
    else
      cb(template.parse_oplog(r.stdout))
    end
  end)
end

--- The change-id of @ (the working copy).
---@param cb fun(id: string)
function M.current(cb)
  runner.spawn({ "log", "--no-graph", "-r", "@", "-T", "change_id" }, opts(), function(r)
    cb(r.code == 0 and vim.trim(r.stdout) or "")
  end)
end

--- Run a mutating command, then invoke cb (used by actions/).
---@param args string[]
---@param cb fun(r: curate.RunResult)|nil
function M.run(args, cb)
  runner.spawn(args, opts(), cb)
end

return M
