-- spec/p9_spec.lua — P9 sticky-arg integration: the flags the menus append must
-- reach jj and behave. Here: the rebase transient's --skip-emptied. (The push
-- --remote / --dry-run and fetch --all-remotes validity live in sync_spec, which
-- already has a remote fixture.)

local H = require("spec.helpers.jj_repo")

describe("P9 rebase sticky args (integration)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local dir
  local function id_of(rev)
    return vim.trim(
      H.jj(dir, { "log", "-r", rev, "--no-graph", "-T", "change_id.short(8)" }).stdout
    )
  end
  local function ids()
    return H.jj(dir, { "log", "--no-graph", "-T", 'change_id.short(8) ++ "\\n"' }).stdout
  end

  before_each(function()
    dir = H.make()
    vim.fn.chdir(dir)
    vim.env.HOME = dir .. "/.home"
    require("curate.config").apply({})
  end)

  it("rebase --skip-emptied abandons a commit that empties on rebase", function()
    -- base has "a"; X and its sibling Y both add the same "Z" line. Rebasing X
    -- onto Y makes X's diff a no-op → --skip-emptied abandons it.
    H.write(dir, "f.txt", "a\n")
    H.jj(dir, { "describe", "-m", "base" })
    local base = id_of("@")
    H.jj(dir, { "new", "-m", "X" })
    H.write(dir, "f.txt", "a\nZ\n")
    H.jj(dir, { "status" })
    local x = id_of("@")
    H.jj(dir, { "new", base, "-m", "Y" })
    H.write(dir, "f.txt", "a\nZ\n")
    H.jj(dir, { "status" })
    local y = id_of("@")
    assert.is_truthy(ids():find(x, 1, true), "X exists before rebase")

    -- exactly the argv the rebase transient's "onto" action builds with the arg
    local runner = require("curate.jj.runner")
    local r = runner.sync({ "rebase", "-s", x, "-d", y, "--skip-emptied" }, { cwd = dir })
    assert.equals(0, r.code, "--skip-emptied must be a valid jj flag: " .. (r.stderr or ""))
    assert.is_falsy(ids():find(x, 1, true), "X emptied onto Y → abandoned by --skip-emptied")
  end)
end)
