-- Integration: drive the status home against a real jj repo inside headless nvim.

local H = require("spec.helpers.jj_repo")

describe("views.status (integration)", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  local dir
  before_each(function()
    dir = H.make()
    H.write(dir, "hunks.lua", "local M = {}\nreturn M\n")
    H.jj(dir, { "describe", "-m", "feat: collector" })
    H.jj(dir, { "new" })
    H.write(dir, "hunks.lua", "local M = {}\nfunction M.collect() end\nreturn M\n")
    H.write(dir, "status.lua", "return 1\n")
    vim.fn.chdir(dir)
    require("curate.config").apply({})
  end)

  --- Pump the event loop until predicate or timeout.
  local function wait_for(pred)
    return vim.wait(3000, pred, 20)
  end

  it("renders @ header, the working diff tree, and the log", function()
    local status = require("curate.views.status").open()
    assert.is_true(wait_for(function()
      local lines = vim.api.nvim_buf_get_lines(status.buf, 0, -1, false)
      return #lines > 3 and table.concat(lines, "\n"):find("Working copy changes") ~= nil
    end))
    local text = table.concat(vim.api.nvim_buf_get_lines(status.buf, 0, -1, false), "\n")
    assert.is_truthy(text:find("@ ")) -- working-copy header
    assert.is_truthy(text:find("hunks%.lua"))
    assert.is_truthy(text:find("status%.lua"))
    assert.is_truthy(text:find("Log"))
    assert.is_truthy(text:find("feat: collector"))
    status:close()
  end)

  it("new change adds a fresh empty @ on top", function()
    local before =
      H.jj(dir, { "log", "--no-graph", "-r", "all()", "-T", 'change_id ++ "\\n"' }).stdout
    local n_before = #vim.split(vim.trim(before), "\n")
    require("curate.views.status").open()
    wait_for(function()
      return require("curate.ui.view").get("status") ~= nil
    end)
    require("curate.actions.name").new()
    assert.is_true(wait_for(function()
      local after =
        H.jj(dir, { "log", "--no-graph", "-r", "all()", "-T", 'change_id ++ "\\n"' }).stdout
      return #vim.split(vim.trim(after), "\n") == n_before + 1
    end))
  end)

  it("undo reverts the last operation", function()
    require("curate.views.status").open()
    wait_for(function()
      return require("curate.ui.view").get("status") ~= nil
    end)
    require("curate.actions.name").new()
    local count = function()
      local s = H.jj(dir, { "log", "--no-graph", "-r", "all()", "-T", 'change_id ++ "\\n"' }).stdout
      return #vim.split(vim.trim(s), "\n")
    end
    wait_for(function()
      return count() >= 4
    end)
    local peak = count()
    require("curate.actions.trust").undo()
    assert.is_true(wait_for(function()
      return count() == peak - 1
    end))
  end)
end)
