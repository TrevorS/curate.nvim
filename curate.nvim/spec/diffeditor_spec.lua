-- Integration test for the diff-editor render pipeline: given two trees, it
-- lays word-level emphasis extmarks on exactly the changed tokens (which also
-- exercises the whole-file syntax pass underneath). No jj needed — the editor
-- reads $left/$right straight off disk.

local DE = require("curate.views.diffeditor")

describe("diff-editor render (integration)", function()
  local function render(old, new)
    require("curate.config").apply({})
    require("curate.ui.highlights").setup()
    local base = vim.fn.tempname()
    local L, R = base .. "/L", base .. "/R"
    vim.fn.mkdir(L, "p")
    vim.fn.mkdir(R, "p")
    vim.fn.writefile(old, L .. "/config.lua")
    vim.fn.writefile(new, R .. "/config.lua")

    local ed = DE.new(L, R, "split", base .. "/result")
    ed.buf = vim.api.nvim_create_buf(false, true)
    ed.win = vim.api.nvim_get_current_win()
    ed:render()

    local lines = vim.api.nvim_buf_get_lines(ed.buf, 0, -1, false)
    local emph = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(ed.buf, ed.ns, 0, -1, { details = true })) do
      local g = m[4] and m[4].hl_group
      if g == "CurateAddedText" or g == "CurateRemovedText" then
        emph[#emph + 1] = { g = g, text = (lines[m[2] + 1] or ""):sub(m[3] + 1, m[4].end_col) }
      end
    end
    return emph
  end

  local function texts(emph, group)
    local out = {}
    for _, e in ipairs(emph) do
      if e.g == group then
        out[#out + 1] = e.text
      end
    end
    table.sort(out)
    return out
  end

  it("emphasises only the changed tokens on modified lines", function()
    local emph = render({ 'theme = "dark",', "font_size = 12," }, {
      'theme = "catppuccin-mocha",',
      "font_size = 14,",
    })
    assert.same({ "12", "dark" }, texts(emph, "CurateRemovedText"))
    assert.same({ "14", "catppuccin-mocha" }, texts(emph, "CurateAddedText"))
  end)

  it("adds no emphasis for a pure insertion", function()
    local emph = render({ "a = 1", "b = 2" }, { "a = 1", "c = 3", "b = 2" })
    assert.same({}, texts(emph, "CurateAddedText"))
    assert.same({}, texts(emph, "CurateRemovedText"))
  end)
end)
