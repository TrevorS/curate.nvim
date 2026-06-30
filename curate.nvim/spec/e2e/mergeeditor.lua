-- spec/e2e/mergeeditor.lua — end-to-end test of the P4 merge-editor.
--
-- Run via:  nvim -l spec/e2e/mergeeditor.lua
--
-- Drives a real `jj resolve` with curate registered as ui.merge-editor: jj ->
-- shim -> nvim --remote-expr -> 3-way buffer -> $output -> jj records the
-- resolution. Like the diff-editor e2e, this needs an RPC server loop the
-- busted/nlua runner can't pump, so it lives as a standalone `nvim -l` script.

local root = vim.uv.cwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
vim.opt.runtimepath:prepend(root)

local failures = 0
local function check(name, cond, detail)
  if cond then
    io.write("  ok   " .. name .. "\n")
  else
    failures = failures + 1
    io.write("  FAIL " .. name .. (detail and ("  — " .. detail) or "") .. "\n")
  end
end

require("curate").setup({})
local ME = require("curate.views.mergeeditor")

-- ── fixture: a 2-sided conflict on one line of f.txt ──
-- base: line2 = X ; c1 (left): line2 = A ; c2 (right): line2 = B ; rebase c2
-- onto c1 → c2 is conflicted.
local function new_conflict_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local home = dir .. "/.home"
  vim.fn.mkdir(home, "p")
  local env = { HOME = home, PATH = vim.env.PATH }
  local function jj(args)
    return vim
      .system(
        vim.list_extend({ "jj", "--no-pager", "--color=never" }, args),
        { cwd = dir, env = env, text = true }
      )
      :wait()
  end
  local function put(s)
    local f = assert(io.open(dir .. "/f.txt", "w"))
    f:write(s)
    f:close()
  end
  local function id(rev)
    return vim.trim(jj({ "log", "-r", rev, "--no-graph", "-T", "change_id.short(8)" }).stdout)
  end
  jj({ "git", "init", "." })
  jj({ "config", "set", "--user", "user.name", "E2E" })
  jj({ "config", "set", "--user", "user.email", "e2e@curate.nvim" })
  put("line1\nX\nline3\n")
  jj({ "describe", "-m", "base" })
  local base = id("@")
  jj({ "new", base, "-m", "c1" })
  put("line1\nA\nline3\n")
  local c1 = id("@")
  jj({ "new", base, "-m", "c2" })
  put("line1\nB\nline3\n")
  local c2 = id("@")
  jj({ "rebase", "-r", c2, "-d", c1 }) -- conflict in c2
  return dir, env, jj, c2
end

local function has_conflict(jj)
  local r = jj({ "resolve", "--list" })
  return (r.stdout or ""):find("f.txt") ~= nil
end

local function run_resolve(dir, env, rev, on_open)
  local server = vim.fn.serverstart()
  local shim = vim.api.nvim_get_runtime_file("bin/curate-diff-shim", false)[1]
  assert(shim, "shim must be on runtimepath")
  local done = {}
  vim.system({
    "jj",
    "--no-pager",
    "--color=never",
    "resolve",
    "-r",
    rev,
    "--config",
    "ui.merge-editor=curate",
    "--config",
    "merge-tools.curate.program=" .. shim,
    "--config",
    'merge-tools.curate.merge-args=["$base","$left","$right","$output"]',
    "--config",
    "merge-tools.curate.merge-tool-edits-conflict-markers=false",
  }, {
    cwd = dir,
    env = { CURATE_SERVER = server, CURATE_MODE = "merge", HOME = env.HOME, PATH = vim.env.PATH },
    text = true,
  }, function(r)
    done.code = r.code
    done.stderr = r.stderr
  end)
  local opened = vim.wait(8000, function()
    return ME._active ~= nil
  end, 25)
  if opened then
    on_open(ME._active)
  end
  vim.wait(8000, function()
    return done.code ~= nil
  end, 25)
  pcall(vim.fn.serverstop, server)
  return opened, done
end

-- ── scenario 1: resolve by choosing the left side → conflict clears, content
--    becomes the left version ──
io.write("scenario: resolve a 2-sided conflict by choosing left\n")
do
  local dir, env, jj, c2 = new_conflict_repo()
  check("repo starts conflicted", has_conflict(jj))
  local seg_count
  local opened, done = run_resolve(dir, env, c2, function(ed)
    seg_count = 0
    for _, s in ipairs(ed.segs) do
      if s.kind == "conflict" then
        seg_count = seg_count + 1
        s.choice = "left"
      end
    end
    ed:confirm()
  end)
  check("merge editor opened", opened)
  check("editor saw exactly one conflict", seg_count == 1, "got " .. tostring(seg_count))
  check(
    "jj resolve succeeded",
    done.code == 0,
    "code=" .. tostring(done.code) .. " " .. tostring(done.stderr)
  )
  check("conflict cleared", not has_conflict(jj))
  local f = vim.trim(jj({ "file", "show", "-r", c2, "f.txt" }).stdout)
  check("resolved content is the left side", f == "line1\nA\nline3", "got: " .. vim.inspect(f))
end

-- ── scenario 2: abort leaves the conflict in place ──
io.write("scenario: abort leaves the conflict\n")
do
  local dir, env, jj, c2 = new_conflict_repo()
  local opened = run_resolve(dir, env, c2, function(ed)
    ed:abort()
  end)
  check("merge editor opened", opened)
  check("still conflicted after abort", has_conflict(jj))
end

io.write("\n")
if failures == 0 then
  io.write("e2e merge-editor: ALL PASS\n")
  os.exit(0)
else
  io.write(("e2e merge-editor: %d FAILURE(S)\n"):format(failures))
  os.exit(1)
end
