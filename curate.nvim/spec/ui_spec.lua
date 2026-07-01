-- Tests for the ui mechanism layer: render row-builder, tree flattening, View base.

local render = require("curate.ui.render")
local tree = require("curate.ui.tree")
local View = require("curate.ui.view")
local highlights = require("curate.ui.highlights")

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

describe("render.row builder — spans and line background", function()
  it("re-bases pre-computed spans onto the row's current column", function()
    local spans = { { "@keyword", 0, 5 }, { "@variable", 6, 9 } }
    local r = render.row():add("    + ", "CurateAdded"):add_spans("local abc", spans):done()
    assert.equals("    + local abc", r[1])
    -- gutter span, then the two rebased spans (offset by 6 bytes)
    assert.equals("CurateAdded", r[2][1][1])
    assert.same({ "@keyword", 6, 11 }, r[2][2])
    assert.same({ "@variable", 12, 15 }, r[2][3])
  end)

  it("carries a line background as the row's third element", function()
    local r = render.row():add("x", "CurateAdded"):line_bg("CurateAddedLine"):done()
    assert.equals("CurateAddedLine", r[3])
    -- absent by default
    assert.is_nil(render.row():add("x"):done()[3])
  end)
end)

describe("syntax spans", function()
  local syntax = require("curate.ui.syntax")

  it("resolves a treesitter language from a file path", function()
    -- lua ships with Neovim; if a build lacks it, skip rather than fail.
    if not pcall(vim.treesitter.language.add, "lua") then
      return
    end
    assert.equals("lua", syntax.lang_for("router.lua"))
    assert.is_nil(syntax.lang_for("notes.unknownext"))
  end)

  it("emits foreground capture spans for a line of code", function()
    if not pcall(vim.treesitter.language.add, "lua") then
      return
    end
    local spans = syntax.spans("local x = 1", "lua")
    assert.is_true(#spans > 0)
    local groups = {}
    for _, s in ipairs(spans) do
      groups[s[1]] = true
      assert.is_true(s[3] > s[2]) -- non-empty range
    end
    assert.is_true(groups["@keyword"] ~= nil) -- `local`
  end)

  it("returns nothing for an unknown language (caller falls back)", function()
    assert.same({}, syntax.spans("whatever", nil))
    assert.same({}, syntax.spans("", "lua"))
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

describe("highlights", function()
  -- Resolve a group through its link chain to a concrete definition.
  local function resolved(group)
    return vim.api.nvim_get_hl(0, { name = group, link = false })
  end

  it("links every painted group so it inherits the colorscheme", function()
    highlights.setup()
    -- A group is wired iff, after following links, it has a fg/bg/reverse.
    for _, g in ipairs({
      "CurateChangeId",
      "CurateSubject",
      "CurateCurrent",
      "CurateFile",
      "CurateHunkHeader",
      "CurateGraph",
      "CurateHint",
      "CurateAgo",
    }) do
      local h = resolved(g)
      assert.is_true(h.fg ~= nil or h.bg ~= nil or h.reverse == true, g .. " has no color")
    end
  end)

  it(
    "gives diff/state TEXT groups a foreground even when DiffAdd/DiffDelete are bg-only",
    function()
      -- Modern colorschemes (catppuccin, tokyonight, …) define DiffAdd/DiffDelete
      -- as background-only. These curate groups are painted on text spans, so they
      -- must resolve to a *foreground* color regardless. Regression guard: linking
      -- them back to DiffAdd/DiffDelete would fail this under such a theme.
      vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#003300" })
      vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#330000" })
      highlights.setup()
      for _, g in ipairs({ "CurateAdded", "CurateRemoved", "CurateConflict", "CurateSelected" }) do
        assert.is_truthy(resolved(g).fg, g .. " must resolve to a foreground color")
      end
    end
  )
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
