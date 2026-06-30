-- Pure unit tests for the diff-editor hunk engine — the heart of the wedge.

local hunks = require("curate.diffeditor.hunks")

local function lines(s)
  return vim.split(s, "\n", { plain = true })
end

describe("hunks.compute", function()
  it("finds a single mid-file modification", function()
    local h = hunks.compute(lines("a\nb\nc"), lines("a\nB\nc"))
    assert.equals(1, #h)
    assert.equals(2, h[1].old_start)
    assert.equals(1, h[1].old_count)
    assert.same({ "b" }, h[1].old_lines)
    assert.same({ "B" }, h[1].new_lines)
  end)

  it("finds a pure insertion (old_count 0)", function()
    local h = hunks.compute(lines("a\nc"), lines("a\nb\nc"))
    assert.equals(1, #h)
    assert.equals(0, h[1].old_count)
    assert.same({ "b" }, h[1].new_lines)
  end)

  it("finds two independent hunks", function()
    local h = hunks.compute(lines("a\nb\nc\nd\ne"), lines("A\nb\nc\nD\ne"))
    assert.equals(2, #h)
    assert.same({ "a" }, h[1].old_lines)
    assert.same({ "d" }, h[2].old_lines)
  end)

  it("handles added file (empty old)", function()
    local h = hunks.compute({}, lines("x\ny"))
    assert.equals(1, #h)
    assert.equals(0, h[1].old_count)
    assert.same({ "x", "y" }, h[1].new_lines)
  end)
end)

describe("hunks.apply", function()
  it("all selected reproduces the new file", function()
    local old = lines("a\nb\nc\nd\ne")
    local new = lines("A\nb\nc\nD\ne")
    local h = hunks.compute(old, new)
    local out = hunks.apply(old, h, { [1] = true, [2] = true })
    assert.same(new, out)
  end)

  it("none selected reproduces the old file", function()
    local old = lines("a\nb\nc\nd\ne")
    local new = lines("A\nb\nc\nD\ne")
    local h = hunks.compute(old, new)
    local out = hunks.apply(old, h, {})
    assert.same(old, out)
  end)

  it("partial selection mixes old and new per hunk (the split gesture)", function()
    local old = lines("a\nb\nc\nd\ne")
    local new = lines("A\nb\nc\nD\ne")
    local h = hunks.compute(old, new)
    -- keep hunk 1 (A), drop hunk 2 (d stays)
    local out = hunks.apply(old, h, { [1] = true })
    assert.same(lines("A\nb\nc\nd\ne"), out)
    -- inverse
    local out2 = hunks.apply(old, h, { [2] = true })
    assert.same(lines("a\nb\nc\nD\ne"), out2)
  end)

  it("round-trips a realistic multi-hunk edit", function()
    local old = lines("local M = {}\nfunction M.collect() end\nreturn M")
    local new = lines(
      "local M = {}\nlocal sel = {}\nfunction M.collect() end\nfunction M.apply() end\nreturn M"
    )
    local h = hunks.compute(old, new)
    assert.is_true(#h >= 1)
    assert.same(
      new,
      hunks.apply(
        old,
        h,
        (function()
          local s = {}
          for i = 1, #h do
            s[i] = true
          end
          return s
        end)()
      )
    )
    assert.same(old, hunks.apply(old, h, {}))
  end)
end)
