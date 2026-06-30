-- spec/inspect_spec.lua — P7: revset workbench (live recompute) + annotate
-- (blame parse + scroll-bind). Drives the real jj binary.

local H = require("spec.helpers.jj_repo")

describe("P7 inspect (integration)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local dir
  local function wait_for(p)
    return vim.wait(4000, p, 25)
  end

  before_each(function()
    dir = H.make()
    H.write(dir, "f.txt", "alpha\nbeta\ngamma\n")
    H.jj(dir, { "describe", "-m", "first" })
    H.jj(dir, { "new", "-m", "second" })
    H.write(dir, "f.txt", "ALPHA\nbeta\ngamma\n")
    H.jj(dir, { "new", "-m", "third" })
    vim.fn.chdir(dir)
    vim.env.HOME = H.env().HOME
    require("curate.config").apply({})
  end)

  it("revset workbench recomputes the log live as the query changes", function()
    local rv = require("curate.views.revset")
    local v = rv.open()

    v:set_query("@")
    v:recompute()
    assert.is_true(
      wait_for(function()
        return #v.changes == 1
      end),
      "query '@' should match exactly one change"
    )

    v:set_query("all()")
    v:recompute()
    assert.is_true(
      wait_for(function()
        return #v.changes >= 4 -- first, second, third, root
      end),
      "query 'all()' should match every change, got " .. tostring(#v.changes)
    )

    v:close()
  end)

  it("revset workbench surfaces an error for a bad query without crashing", function()
    local rv = require("curate.views.revset")
    local v = rv.open()
    v:set_query("this_is_not_a_function()")
    v:recompute()
    -- it should simply render no matches / an error line, not throw
    assert.is_true(wait_for(function()
      local lines = vim.api.nvim_buf_get_lines(v.buf, 1, -1, false)
      return #lines > 0
    end))
    v:close()
  end)

  it("annotate parses blame and the gutter aligns per line", function()
    local annotate = require("curate.views.annotate")
    local US = "\31"
    local sample = table.concat({
      "abcd1234" .. US .. "2 minutes ago" .. US .. "alpha",
      "wxyz7890" .. US .. "1 minute ago" .. US .. "beta",
    }, "\n")
    local recs = annotate.parse(sample)
    assert.are.equal(2, #recs)
    assert.are.equal("abcd1234", recs[1].id)
    assert.are.equal("alpha", recs[1].content)
    local gutter = annotate.gutter(recs)
    assert.are.equal(2, #gutter)
    -- both gutter lines share the id column width
    assert.are.equal(#gutter[1]:match("^%S+"), 8)
  end)

  it("annotate opens a gutter window scroll-bound to the source", function()
    local annotate = require("curate.views.annotate")
    -- open the real file in a window
    vim.cmd("edit " .. dir .. "/f.txt")
    local src_win = vim.api.nvim_get_current_win()
    local done = false
    annotate.open({ file = dir .. "/f.txt", rev = "@", win = src_win })
    assert.is_true(
      wait_for(function()
        done = annotate._active ~= nil
        return done
      end),
      "annotate window should open"
    )
    local a = annotate._active
    assert.is_true(vim.wo[a.win].scrollbind, "gutter window should be scroll-bound")
    assert.is_true(vim.wo[a.src_win].scrollbind, "source window should be scroll-bound")
    -- gutter has one line per source line (3)
    local n = #vim.api.nvim_buf_get_lines(a.buf, 0, -1, false)
    assert.are.equal(3, n)
    a.close()
  end)
end)
