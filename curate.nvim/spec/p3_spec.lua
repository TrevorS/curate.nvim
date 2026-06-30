-- Integration tests for P3: absorb, squash, the op-log time machine.

local H = require("spec.helpers.jj_repo")

describe("P3 route + trust (integration)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local dir
  local function wait_for(p)
    return vim.wait(3000, p, 20)
  end
  local function at_empty()
    -- is @ empty (no diff vs parent)?
    return vim.trim(H.jj(dir, { "diff", "-r", "@", "--git" }).stdout) == ""
  end

  before_each(function()
    dir = H.make()
    H.write(dir, "a.txt", "l1\nl2\nl3\n")
    H.jj(dir, { "describe", "-m", "base a" })
    H.jj(dir, { "new" })
    vim.fn.chdir(dir)
    require("curate.config").apply({})
  end)

  it("absorb routes @'s edits into the owning ancestor and empties @", function()
    H.write(dir, "a.txt", "l1-mod\nl2\nl3\n") -- edits a line base owns
    assert.is_false(at_empty())
    require("curate.actions.route").absorb()
    assert.is_true(wait_for(at_empty), "@ should be empty after absorb")
  end)

  it("squash folds @'s diff into its parent, leaving @ empty", function()
    H.write(dir, "a.txt", "l1\nl2\nl3\nl4-new\n")
    H.jj(dir, { "describe", "-m", "child" })
    H.jj(dir, { "new" }) -- fresh empty @ so squash target is 'child'
    H.write(dir, "a.txt", "l1\nl2\nl3\nl4-new\nl5-new\n")
    assert.is_false(at_empty())
    require("curate.actions.route").squash()
    -- @ becomes empty; the parent now carries the l5-new line.
    assert.is_true(wait_for(at_empty), "@ should be empty after squash")
    local parent = H.jj(dir, { "file", "show", "-r", "@-", "a.txt" }).stdout
    assert.is_truthy(parent:find("l5%-new"), "parent should contain the squashed line")
  end)

  it("op-log renders operations and restore is append-only", function()
    -- make an op to see
    H.write(dir, "a.txt", "l1\nl2\nl3\nX\n")
    H.jj(dir, { "describe", "-m", "edit" })
    local ops_before = #vim.split(
      vim.trim(H.jj(dir, { "op", "log", "--no-graph", "-T", 'self.id() ++ "\\n"' }).stdout),
      "\n"
    )

    local view = require("curate.views.oplog").open()
    assert.is_true(
      wait_for(function()
        return #view.ops > 0
      end),
      "op-log should populate"
    )
    assert.is_truthy(view.ops[1].current, "newest op marked current")

    -- restore to an older op; this must ADD an op (append-only), not remove.
    local target = view.ops[3] or view.ops[#view.ops]
    require("curate.actions.trust").op_restore(target.id)
    assert.is_true(
      wait_for(function()
        local n = #vim.split(
          vim.trim(H.jj(dir, { "op", "log", "--no-graph", "-T", 'self.id() ++ "\\n"' }).stdout),
          "\n"
        )
        return n > ops_before
      end),
      "restore writes a new op (append-only)"
    )
    view:close()
  end)
end)
