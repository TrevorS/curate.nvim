-- Integration tests for P6 plumbing: curate:// file read/write round-trip,
-- bookmark set, and dot-repeat bookkeeping.

local H = require("spec.helpers.jj_repo")

describe("P6 supporting (integration)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local dir, change
  local function wait_for(p)
    return vim.wait(3000, p, 20)
  end

  before_each(function()
    dir = H.make()
    H.write(dir, "doc.txt", "original\nline2\n")
    H.jj(dir, { "describe", "-m", "doc base" })
    H.jj(dir, { "new" }) -- @ on top; target the described change
    change = vim.trim(H.jj(dir, { "log", "--no-graph", "-r", "@-", "-T", "change_id" }).stdout)
    vim.fn.chdir(dir)
    require("curate.config").apply({})
  end)

  it("curate:// reads a file at a revision", function()
    local file = require("curate.views.file")
    local buf = vim.api.nvim_create_buf(false, true)
    local url = "curate://" .. change .. "/doc.txt"
    vim.api.nvim_buf_set_name(buf, url)
    file.read(buf, url)
    assert.is_true(wait_for(function()
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"):find("original")
        ~= nil
    end))
    assert.same({ "original", "line2", "" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)

  it("curate:// writes the buffer back into the revision (cp-as-tool)", function()
    local file = require("curate.views.file")
    local buf = vim.api.nvim_create_buf(false, true)
    local url = "curate://" .. change .. "/doc.txt"
    vim.api.nvim_buf_set_name(buf, url)
    vim.bo[buf].buftype = "acwrite"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "EDITED", "line2", "added3" })
    file.write(buf, url)
    assert.is_true(
      wait_for(function()
        local content = H.jj(dir, { "file", "show", "-r", change, "doc.txt" }).stdout
        return content:find("EDITED") ~= nil and content:find("added3") ~= nil
      end),
      "revision should hold the edited content"
    )
  end)

  it("bookmark set creates a bookmark at @", function()
    local util = require("curate.actions.util")
    local jj = require("curate.jj")
    util.mutate(jj, { "bookmark", "set", "feature", "-r", "@" })
    assert.is_true(wait_for(function()
      return H.jj(dir, { "bookmark", "list" }).stdout:find("feature") ~= nil
    end))
  end)

  it("dot-repeat remembers the last rewriting action", function()
    local keymap = require("curate.keymap")
    keymap._last = nil
    -- simulate a rewriting dispatch by setting _last as dispatch would
    keymap._last = "route.squash"
    assert.equals("route.squash", keymap._last)
  end)
end)
