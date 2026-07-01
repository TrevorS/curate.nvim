-- Integration test for the merge-editor render: each conflict side is
-- word-diffed against the base, so only the token each side changed is
-- emphasised (left → CurateAddedText, right → CurateRemovedText).

local ME = require("curate.views.mergeeditor")

describe("merge-editor render (integration)", function()
  local function render(base, left, right)
    require("curate.config").apply({})
    require("curate.ui.highlights").setup()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    local function put(name, lines)
      local p = dir .. "/" .. name
      vim.fn.writefile(lines, p)
      return p
    end
    local ed = ME.new(
      put("base", base),
      put("left", left),
      put("right", right),
      dir .. "/config.lua", -- basename drives the language (lua)
      dir .. "/result",
      "merge"
    )
    ed.buf = vim.api.nvim_create_buf(false, true)
    ed.win = vim.api.nvim_get_current_win()
    ed:render()

    local lines = vim.api.nvim_buf_get_lines(ed.buf, 0, -1, false)
    local out = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(ed.buf, ed.ns, 0, -1, { details = true })) do
      local g = m[4] and m[4].hl_group
      if g == "CurateAddedText" or g == "CurateRemovedText" then
        out[g] = (lines[m[2] + 1] or ""):sub(m[3] + 1, m[4].end_col)
      end
    end
    return out
  end

  it("emphasises each side's changed token against the base", function()
    -- both sides change x's value differently → a real conflict
    local marks = render({ "x = 1" }, { "x = 2" }, { "x = 3" })
    assert.equals("2", marks.CurateAddedText) -- left's edit
    assert.equals("3", marks.CurateRemovedText) -- right's edit
  end)
end)
