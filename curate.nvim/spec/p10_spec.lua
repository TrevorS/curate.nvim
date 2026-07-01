-- spec/p10_spec.lua — op-log --limit plumbing and the abandon menu's flags,
-- against real jj. Guards that the sticky-arg flags these menus append are
-- valid and behave.

local H = require("spec.helpers.jj_repo")

describe("P10 op-log limit + abandon flags (integration)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local dir
  before_each(function()
    dir = H.make()
    vim.fn.chdir(dir)
    vim.env.HOME = dir .. "/.home"
    require("curate.config").apply({})
  end)

  it("op-log --limit caps how many operations jj.oplog returns", function()
    for i = 1, 3 do
      H.write(dir, "f.txt", "v" .. i .. "\n")
      H.jj(dir, { "describe", "-m", "op" .. i })
    end
    local jj = require("curate.jj")

    local all
    jj.oplog(function(ops)
      all = ops
    end)
    assert.is_true(vim.wait(3000, function()
      return all ~= nil
    end, 25))
    assert.is_true(#all >= 3, "several ops exist")

    local limited
    jj.oplog(function(ops)
      limited = ops
    end, { "--limit", "2" })
    assert.is_true(vim.wait(3000, function()
      return limited ~= nil
    end, 25))
    assert.equals(2, #limited, "--limit 2 caps to 2 ops")
  end)

  it("op-log reports a jj error for a junk --limit instead of empty ops", function()
    -- The view relies on this err to keep its last good render (and notify)
    -- rather than silently blanking when the user types a non-numeric limit.
    local jj = require("curate.jj")
    local got_err
    jj.oplog(function(_, err)
      got_err = err
    end, { "--limit", "not-a-number" })
    assert.is_true(vim.wait(3000, function()
      return got_err ~= nil
    end, 25))
    assert.is_true(got_err ~= "", "jj must surface the bad-flag error")
  end)

  it("abandon accepts the menu's --restore-descendants flag", function()
    -- guards a bad flag: run the exact argv abandon_menu builds and assert exit 0
    H.write(dir, "f.txt", "a\n")
    H.jj(dir, { "describe", "-m", "base" })
    H.jj(dir, { "new", "-m", "x" })
    local x =
      vim.trim(H.jj(dir, { "log", "-r", "@", "--no-graph", "-T", "change_id.short(8)" }).stdout)
    local runner = require("curate.jj.runner")
    local r = runner.sync({ "abandon", "-r", x, "--restore-descendants" }, { cwd = dir })
    assert.equals(0, r.code, "--restore-descendants must be a valid jj flag: " .. (r.stderr or ""))
  end)
end)
