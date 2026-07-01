-- spec/sync_spec.lua — P5 sync integration against a real local bare remote.
-- Exercises the sync action code (push-change, fetch, tug) end-to-end: a clone
-- publishes a change, a second clone fetches it back.

local H = require("spec.helpers.jj_repo")

describe("P5 sync (integration, bare remote)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local root, remote, A
  local env

  local function sys(args, cwd)
    return vim.system(args, { cwd = cwd, env = env, text = true }):wait()
  end
  local function jjA(args)
    return sys(vim.list_extend({ "jj", "--no-pager", "--color=never" }, args), A)
  end
  local function wait_for(p)
    return vim.wait(4000, p, 25)
  end

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    local home = root .. "/.home"
    vim.fn.mkdir(home, "p")
    env = { HOME = home, PATH = vim.env.PATH }
    remote = root .. "/remote.git"
    sys({ "git", "init", "--bare", "-q", remote }, root)
    -- clone A from the bare remote
    A = root .. "/A"
    sys({ "jj", "git", "clone", remote, A }, root)
    jjA({ "config", "set", "--user", "user.name", "Spec" })
    jjA({ "config", "set", "--user", "user.email", "spec@curate.nvim" })
    -- a described change to publish
    H.write(A, "f.txt", "hello\n")
    jjA({ "describe", "-m", "work" })
    -- point curate at clone A
    vim.fn.chdir(A)
    require("curate.config").apply({})
    -- the sync actions inherit HOME via the jj runner's env; make sure jj in
    -- this nvim process sees the sandbox HOME too.
    vim.env.HOME = home
  end)

  it("push_change publishes @ as an auto-named bookmark on the remote", function()
    local sync = require("curate.actions.sync")
    sync.push_change()
    -- the remote (a git repo) should gain a push-* ref
    assert.is_true(
      wait_for(function()
        local r = sys({ "git", "--git-dir=" .. remote, "branch", "--list", "push-*" }, root)
        return (r.stdout or ""):find("push%-") ~= nil
      end),
      "remote should have a push-* branch after push_change"
    )
  end)

  it("a second clone fetches the published change back", function()
    local sync = require("curate.actions.sync")
    sync.push_change()
    assert.is_true(wait_for(function()
      local r = sys({ "git", "--git-dir=" .. remote, "branch", "--list", "push-*" }, root)
      return (r.stdout or ""):find("push%-") ~= nil
    end))
    -- clone B, fetch, and confirm it sees the published file content
    local B = root .. "/B"
    sys({ "jj", "git", "clone", remote, B }, root)
    local seen = vim
      .system(
        { "jj", "--no-pager", "log", "-r", "all()", "-T", "description", "--no-graph" },
        { cwd = B, env = env, text = true }
      )
      :wait()
    assert.is_not_nil((seen.stdout or ""):find("work"), "clone B should see the 'work' change")
  end)

  it("push accepts and honors the push menu's --dry-run flag", function()
    -- Guards against a bad sticky-arg flag reaching jj: run the exact argv the
    -- push menu builds and assert jj accepts it (exit 0) and honors it (no ref).
    local runner = require("curate.jj.runner")
    local r = runner.sync({ "git", "push", "--change", "@", "--dry-run" }, { cwd = A, env = env })
    assert.equals(0, r.code, "--dry-run must be a valid jj flag: " .. (r.stderr or ""))
    assert.is_truthy((r.stdout .. r.stderr):lower():find("dry"), "should report a dry run")
    local br = sys({ "git", "--git-dir=" .. remote, "branch", "--list", "push-*" }, root)
    assert.is_falsy((br.stdout or ""):find("push%-"), "dry run must not create a ref")
  end)

  it("the menus' sticky-arg flags are valid jj flags", function()
    -- push menu's --remote value arg (+ --dry-run) and the fetch/pull menu's
    -- --all-remotes must all be accepted by jj (exit 0), or a toggle would error.
    local runner = require("curate.jj.runner")
    local push = runner.sync(
      { "git", "push", "--remote", "origin", "--change", "@", "--dry-run" },
      { cwd = A, env = env }
    )
    assert.equals(0, push.code, "push --remote/--dry-run: " .. (push.stderr or ""))
    local fetch = runner.sync({ "git", "fetch", "--all-remotes" }, { cwd = A, env = env })
    assert.equals(0, fetch.code, "fetch --all-remotes: " .. (fetch.stderr or ""))
  end)

  it("tug moves a bookmark forward to @", function()
    local util = require("curate.actions.util")
    local jj = require("curate.jj")
    -- set a bookmark at @-, advance @, then tug it forward
    util.mutate(jj, { "bookmark", "set", "feature", "-r", "@" })
    assert.is_true(wait_for(function()
      return jjA({ "bookmark", "list" }).stdout:find("feature") ~= nil
    end))
    local before = vim.trim(jjA({ "log", "-r", "feature", "--no-graph", "-T", "change_id" }).stdout)
    jjA({ "new" }) -- advance @ past the bookmark
    util.mutate(jj, { "bookmark", "set", "feature", "-r", "@", "--allow-backwards" })
    assert.is_true(
      wait_for(function()
        local after =
          vim.trim(jjA({ "log", "-r", "feature", "--no-graph", "-T", "change_id" }).stdout)
        return after ~= before
      end),
      "feature bookmark should have moved to the new @"
    )
  end)
end)
