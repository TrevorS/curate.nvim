-- spec/p8_spec.lua — P8 command grammar integration tests against real jj.
-- The actions read their target from util.cursor_target(); we stub it to point
-- at a chosen change/file so the tests drive the actual jj verb without opening
-- a view and moving the cursor.

local H = require("spec.helpers.jj_repo")
local util = require("curate.actions.util")

describe("P8 abandon + untrack (integration)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local dir
  local function wait_for(p)
    return vim.wait(4000, p, 25)
  end
  local function ids()
    return H.jj(dir, { "log", "--no-graph", "-T", 'change_id.short(8) ++ "\\n"' }).stdout
  end
  local function files()
    return H.jj(dir, { "file", "list" }).stdout
  end
  -- Run `fn` with cursor_target() forced to `t`, then restore it.
  local function with_target(t, fn)
    local orig = util.cursor_target
    util.cursor_target = function()
      return t
    end
    local ok, err = pcall(fn)
    util.cursor_target = orig
    assert(ok, err)
  end

  before_each(function()
    dir = H.make()
    vim.fn.chdir(dir)
    vim.env.HOME = dir .. "/.home" -- curate's jj runner sees the sandbox identity
    require("curate.config").apply({})
  end)

  it("abandon drops the targeted change and reparents its child", function()
    -- base ← mid ← top(@).  Abandon `mid` (mutable, not @ → no confirm).
    H.write(dir, "a.txt", "base\n")
    H.jj(dir, { "describe", "-m", "base" })
    H.jj(dir, { "new", "-m", "mid" })
    H.write(dir, "b.txt", "mid\n")
    local mid =
      vim.trim(H.jj(dir, { "log", "-r", "@", "--no-graph", "-T", "change_id.short(8)" }).stdout)
    H.jj(dir, { "new", "-m", "top" })
    assert.is_truthy(ids():find(mid, 1, true), "mid should exist before abandon")

    with_target({ type = "change", id = mid, change = { id = mid, flags = {} } }, function()
      require("curate.actions.route").abandon()
    end)

    assert.is_true(
      wait_for(function()
        return not ids():find(mid, 1, true)
      end),
      "mid should be gone after abandon"
    )
  end)

  it("untrack stops tracking a now-ignored file", function()
    H.write(dir, "note.log", "temp\n")
    H.jj(dir, { "status" }) -- snapshot so note.log is tracked
    H.write(dir, ".gitignore", "*.log\n") -- untrack requires it be ignored
    assert.is_truthy(files():find("note.log", 1, true), "note.log tracked before untrack")

    with_target({ type = "file", file = { path = "note.log" } }, function()
      require("curate.actions.files").untrack()
    end)

    assert.is_true(
      wait_for(function()
        return not files():find("note.log", 1, true)
      end),
      "note.log should be untracked"
    )
  end)
end)

describe("P8 pull (integration, bare remote)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local root, remote, A, env
  local function sys(args, cwd)
    return vim.system(args, { cwd = cwd, env = env, text = true }):wait()
  end
  local function jj(cwd, args)
    return sys(vim.list_extend({ "jj", "--no-pager", "--color=never" }, args), cwd)
  end
  local function wait_for(p)
    return vim.wait(6000, p, 25)
  end

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    local home = root .. "/.home"
    vim.fn.mkdir(home, "p")
    env = { HOME = home, PATH = vim.env.PATH }
    remote = root .. "/remote.git"
    sys({ "git", "init", "--bare", "-q", remote }, root)

    -- Seed the remote's `main` from a helper clone S.
    local S = root .. "/S"
    sys({ "jj", "git", "clone", remote, S }, root)
    jj(S, { "config", "set", "--user", "user.name", "Spec" })
    jj(S, { "config", "set", "--user", "user.email", "spec@curate.nvim" })
    H.write(S, "base.txt", "v1\n")
    jj(S, { "describe", "-m", "v1" })
    jj(S, { "bookmark", "set", "main", "-r", "@" })
    jj(S, { "new" })
    jj(S, { "git", "push", "--bookmark", "main", "--allow-new" })

    -- Clone A from the remote; it tracks main, so trunk() = main's head.
    A = root .. "/A"
    sys({ "jj", "git", "clone", remote, A }, root)
    H.write(A, "mine.txt", "local work\n")
    jj(A, { "describe", "-m", "my change" })

    -- Advance the remote main from S (a new commit others pushed).
    H.write(S, "v2.txt", "v2\n")
    jj(S, { "describe", "-m", "v2" })
    jj(S, { "bookmark", "set", "main", "-r", "@", "--allow-backwards" })
    jj(S, { "new" })
    jj(S, { "git", "push", "--bookmark", "main" })

    vim.fn.chdir(A)
    vim.env.HOME = home
    require("curate.config").apply({})
  end)

  it("pull fetches the moved trunk and restacks @ onto it", function()
    -- Before pull, A's parent has no v2.txt.
    assert.is_falsy(jj(A, { "file", "list", "-r", "@-" }).stdout:find("v2.txt", 1, true))

    require("curate.actions.sync").pull()

    -- After pull, @ is rebased onto the new trunk, whose tree carries v2.txt.
    assert.is_true(
      wait_for(function()
        return jj(A, { "file", "list", "-r", "@-" }).stdout:find("v2.txt", 1, true) ~= nil
      end),
      "@ should be restacked onto the fetched trunk (v2.txt present in @-)"
    )
    -- The local edit survived the rebase.
    assert.is_truthy(jj(A, { "file", "list", "-r", "@" }).stdout:find("mine.txt", 1, true))
  end)
end)
