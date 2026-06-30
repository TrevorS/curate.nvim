-- spec/power_spec.lua — P7 power surface actions (duplicate / fix / parallelize).

local H = require("spec.helpers.jj_repo")

describe("P7 power actions (integration)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local dir
  local function wait_for(p)
    return vim.wait(4000, p, 25)
  end
  local function count()
    local r = H.jj(dir, { "log", "-r", "all()", "--no-graph", "-T", 'change_id ++ "\n"' })
    return #vim.split(vim.trim(r.stdout), "\n", { plain = true })
  end

  before_each(function()
    dir = H.make()
    H.write(dir, "f.txt", "one\n")
    H.jj(dir, { "describe", "-m", "first" })
    H.jj(dir, { "new", "-m", "second" })
    vim.fn.chdir(dir)
    vim.env.HOME = H.env().HOME
    require("curate.config").apply({})
    require("curate.actions.reshape")._mark = nil
  end)

  it("duplicate creates a new copy of @ (change count grows)", function()
    local power = require("curate.actions.power")
    local n0 = count()
    power.duplicate()
    assert.is_true(
      wait_for(function()
        return count() == n0 + 1
      end),
      ("expected %d -> %d"):format(n0, n0 + 1)
    )
  end)

  it("parallelize without two targets is a guarded no-op", function()
    local power = require("curate.actions.power")
    local n0 = count()
    -- no mark set; only @ resolvable → should warn and not mutate
    power.parallelize()
    vim.wait(300)
    assert.are.equal(n0, count())
  end)
end)
