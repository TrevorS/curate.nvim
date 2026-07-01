-- Unit tests for the intra-line (word-level) diff.

local wd = require("curate.diffeditor.worddiff")

-- Render a line's changed ranges back to the substrings they cover, for
-- readable assertions.
local function marks(line, ranges)
  local out = {}
  for _, r in ipairs(ranges or {}) do
    out[#out + 1] = line:sub(r[1] + 1, r[2])
  end
  return out
end

describe("worddiff.ranges", function()
  it("emphasises only the inserted tokens in a modified line", function()
    local del, ins = wd.ranges({ "local pattern = path" }, { 'local pattern = "^" .. path' })
    assert.is_nil(del[1]) -- nothing removed on the old line
    assert.same({ '"^"', ".." }, marks('local pattern = "^" .. path', ins[1]))
  end)

  it("emphasises the changed value on both sides", function()
    local del, ins = wd.ranges({ '  theme = "dark",' }, { '  theme = "mocha",' })
    assert.same({ "dark" }, marks('  theme = "dark",', del[1]))
    assert.same({ "mocha" }, marks('  theme = "mocha",', ins[1]))
  end)

  it("skips wholly-different lines that share no word", function()
    local del, ins = wd.ranges({ "return handler(req)" }, { "for _, r in pairs(t) do" })
    assert.is_nil(del[1])
    assert.is_nil(ins[1])
  end)

  it("does not emphasise whitespace-only differences", function()
    local _, ins = wd.ranges({ "x = 1" }, { "x   =   1" })
    -- only spacing changed; the words/operators all match → nothing emphasised
    assert.is_nil(ins[1])
  end)

  it("returns empty for pure insertions or deletions", function()
    local del, ins = wd.ranges({}, { "a", "b" })
    assert.same({}, del)
    assert.same({}, ins)
  end)
end)
