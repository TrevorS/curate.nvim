-- spec/e2e/diffeditor.lua — end-to-end test of the diff-editor wedge.
--
-- Run via:  nvim -l spec/e2e/diffeditor.lua
--
-- This needs a real RPC server loop (jj -> shim -> nvim --remote-expr -> us),
-- which the busted/nlua runner can't pump. A plain `nvim -l` can, so this lives
-- as a standalone integration script invoked by scripts/test.sh.

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
local DE = require("curate.views.diffeditor")

-- ── fixture: a change with two independent hunks in one file ──
local function new_repo()
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
  jj({ "git", "init", "." })
  jj({ "config", "set", "--user", "user.name", "E2E" })
  jj({ "config", "set", "--user", "user.email", "e2e@curate.nvim" })
  local function put(s)
    local f = assert(io.open(dir .. "/f.txt", "w"))
    f:write(s)
    f:close()
  end
  put("a\nb\nc\nd\ne\n")
  jj({ "describe", "-m", "base" })
  jj({ "new" })
  put("A\nb\nc\nD\ne\n") -- modify line 1 and line 4 → two hunks
  return dir, env, jj
end

local function count_changes(jj)
  local r = jj({ "log", "-r", "all()", "--no-graph", "-T", 'change_id ++ "\\n"' })
  return #vim.split(vim.trim(r.stdout), "\n")
end

local function run_split(dir, env, on_open)
  local server = vim.fn.serverstart()
  local shim = vim.api.nvim_get_runtime_file("bin/curate-diff-shim", false)[1]
  assert(shim, "shim must be on runtimepath")
  local done = {}
  vim.system({
    "jj",
    "--no-pager",
    "--color=never",
    "split",
    "-r",
    "@",
    "--config",
    "ui.diff-editor=curate",
    "--config",
    "merge-tools.curate.program=" .. shim,
    "--config",
    'merge-tools.curate.edit-args=["$left","$right"]',
    "--config",
    'ui.editor=["true"]',
  }, {
    cwd = dir,
    env = { CURATE_SERVER = server, CURATE_MODE = "split", HOME = env.HOME, PATH = vim.env.PATH },
    text = true,
  }, function(r)
    done.code = r.code
    done.stderr = r.stderr
  end)
  local opened = vim.wait(8000, function()
    return DE._active ~= nil
  end, 25)
  if opened then
    on_open(DE._active)
  end
  vim.wait(8000, function()
    return done.code ~= nil
  end, 25)
  pcall(vim.fn.serverstop, server)
  return opened, done
end

-- ── scenario 1: select only hunk 1 → split creates one extra change, and the
--    first commit holds only hunk 1's content ──
io.write("scenario: split with partial hunk selection\n")
do
  local dir, env, jj = new_repo()
  local n0 = count_changes(jj)
  local opened, done = run_split(dir, env, function(ed)
    check(
      "editor saw one file with two hunks",
      #ed.files == 1 and #ed.files[1].hunks == 2,
      ("files=%d hunks=%d"):format(#ed.files, ed.files[1] and #ed.files[1].hunks or -1)
    )
    ed.files[1].selected[2] = false -- drop the line-4 hunk
    ed:confirm()
  end)
  check("diff editor opened", opened)
  check(
    "jj split succeeded",
    done.code == 0,
    "code=" .. tostring(done.code) .. " " .. tostring(done.stderr)
  )
  check(
    "split added exactly one change",
    count_changes(jj) == n0 + 1,
    ("%d -> %d"):format(n0, count_changes(jj))
  )
  -- first commit (@-) should have only hunk 1 applied: A b c d e
  local first = jj({ "file", "show", "-r", "@-", "f.txt" }).stdout
  check(
    "first commit holds only the selected hunk",
    vim.trim(first) == "A\nb\nc\nd\ne",
    "got: " .. vim.inspect(first)
  )
end

-- ── scenario 2: abort leaves the repo untouched ──
io.write("scenario: abort with q\n")
do
  local dir, env, jj = new_repo()
  local before =
    vim.trim(jj({ "log", "-r", "all()", "--no-graph", "-T", 'change_id ++ "\\n"' }).stdout)
  local opened = run_split(dir, env, function(ed)
    ed:abort()
  end)
  check("diff editor opened", opened)
  local after =
    vim.trim(jj({ "log", "-r", "all()", "--no-graph", "-T", 'change_id ++ "\\n"' }).stdout)
  check("repo unchanged after abort", before == after)
end

io.write("\n")
if failures == 0 then
  io.write("e2e diff-editor: ALL PASS\n")
  os.exit(0)
else
  io.write(("e2e diff-editor: %d FAILURE(S)\n"):format(failures))
  os.exit(1)
end
