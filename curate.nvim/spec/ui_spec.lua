-- Tests for the ui mechanism layer: render row-builder, tree flattening, View base.

local render = require("curate.ui.render")
local tree = require("curate.ui.tree")
local View = require("curate.ui.view")

describe("render.row builder", function()
  it("tracks byte columns for spans", function()
    local r =
      render.row():add("○ ", "CurateGraph"):add("kkmpptxz", "CurateChangeId"):add(" hi"):done()
    assert.equals("○ kkmpptxz hi", r[1])
    -- two highlighted chunks
    assert.equals(2, #r[2])
    -- '○ ' is 3 bytes (○ is 3-byte UTF-8 + space)... assert second span starts after it
    local graph_span, id_span = r[2][1], r[2][2]
    assert.equals("CurateGraph", graph_span[1])
    assert.equals("CurateChangeId", id_span[1])
    assert.equals(graph_span[3], id_span[2]) -- contiguous
  end)
end)

describe("tree", function()
  local function file(path, nhunks)
    local hunks = {}
    for i = 1, nhunks do
      hunks[i] = { file = path, header = "@@ h" .. i .. " @@", lines = {} }
    end
    return { path = path, status = "M", hunks = hunks, added = 1, removed = 0 }
  end

  it("flattens files then hunks", function()
    local t = tree.new({ file("a.lua", 2), file("b.lua", 1) })
    local nodes = t:nodes()
    -- a (file) + 2 hunks + b (file) + 1 hunk = 5
    assert.equals(5, #nodes)
    assert.equals("file", nodes[1].kind)
    assert.equals("hunk", nodes[2].kind)
    assert.equals(1, nodes[2].hunk_index)
  end)

  it("hides hunks when a file is folded and carries state across rebuilds", function()
    local t = tree.new({ file("a.lua", 2) })
    t:toggle("a.lua")
    assert.equals(1, #t:nodes()) -- just the file row
    local t2 = tree.new({ file("a.lua", 2) }, t) -- carry fold state
    assert.is_true(t2:is_folded("a.lua"))
  end)
end)

describe("View base", function()
  it("opens a scratch buffer with the right filetype and re-focuses singletons", function()
    local Sub = setmetatable({}, { __index = View })
    Sub.__index = Sub
    function Sub.new()
      local self = View.new("test")
      return setmetatable(self, Sub)
    end
    function Sub:render()
      self:set_lines({ "line one", "line two" })
    end

    local v = Sub.new():open({ split = "right" })
    assert.is_true(v:valid())
    assert.equals("curate-test", vim.bo[v.buf].filetype)
    assert.equals("nofile", vim.bo[v.buf].buftype)
    local lines = vim.api.nvim_buf_get_lines(v.buf, 0, -1, false)
    assert.same({ "line one", "line two" }, lines)
    assert.is_false(vim.bo[v.buf].modifiable)

    -- singleton: View.get returns the same instance
    assert.equals(v, View.get("test"))
    v:close()
    assert.is_nil(View.get("test"))
  end)
end)
