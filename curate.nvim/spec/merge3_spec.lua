-- spec/merge3_spec.lua — the 3-way merge engine (pure, no jj).

local merge3 = require("curate.diffeditor.merge3")

local function lines(s)
  return vim.split(s, "\n", { plain = true })
end

describe("merge3.chunk", function()
  it("auto-merges non-overlapping changes from both sides", function()
    -- base:  1 2 3 4 5
    -- left:  changes line 1 -> A
    -- right: changes line 5 -> E
    local base = lines("1\n2\n3\n4\n5")
    local left = lines("A\n2\n3\n4\n5")
    local right = lines("1\n2\n3\n4\nE")
    local segs = merge3.chunk(base, left, right)
    local unres, total = merge3.unresolved(segs)
    assert.are.equal(0, total) -- no real conflicts
    assert.are.equal(0, unres)
    local out = merge3.assemble(segs)
    assert.are.same({ "A", "2", "3", "4", "E" }, out)
  end)

  it("flags a real conflict when both sides change the same line", function()
    local base = lines("1\n2\n3")
    local left = lines("1\nA\n3")
    local right = lines("1\nB\n3")
    local segs = merge3.chunk(base, left, right)
    local unres, total = merge3.unresolved(segs)
    assert.are.equal(1, total)
    assert.are.equal(1, unres)
    -- unresolved → assemble refuses
    assert.is_nil(merge3.assemble(segs))
  end)

  it("resolves a conflict by the chosen side", function()
    local base = lines("1\n2\n3")
    local left = lines("1\nA\n3")
    local right = lines("1\nB\n3")
    local segs = merge3.chunk(base, left, right)
    for _, s in ipairs(segs) do
      if s.kind == "conflict" then
        s.choice = "left"
      end
    end
    assert.are.same({ "1", "A", "3" }, merge3.assemble(segs))

    for _, s in ipairs(segs) do
      if s.kind == "conflict" then
        s.choice = "right"
      end
    end
    assert.are.same({ "1", "B", "3" }, merge3.assemble(segs))

    for _, s in ipairs(segs) do
      if s.kind == "conflict" then
        s.choice = "left+right"
      end
    end
    assert.are.same({ "1", "A", "B", "3" }, merge3.assemble(segs))
  end)

  it("treats an identical change on both sides as auto (not a conflict)", function()
    local base = lines("1\n2\n3")
    local left = lines("1\nX\n3")
    local right = lines("1\nX\n3")
    local segs = merge3.chunk(base, left, right)
    local _, total = merge3.unresolved(segs)
    assert.are.equal(0, total)
    assert.are.same({ "1", "X", "3" }, merge3.assemble(segs))
  end)

  it("base choice discards both sides' content for that conflict", function()
    local base = lines("1\n2\n3")
    local left = lines("1\nA\n3")
    local right = lines("1\nB\n3")
    local segs = merge3.chunk(base, left, right)
    for _, s in ipairs(segs) do
      if s.kind == "conflict" then
        s.choice = "base"
      end
    end
    assert.are.same({ "1", "2", "3" }, merge3.assemble(segs))
  end)
end)
