-- Tests for the transient popup engine's sticky args: toggling an arg item
-- flips the flag list an action's run() receives.

local transient = require("curate.ui.transient")

describe("transient sticky args", function()
  local function open(items)
    return transient.open({ title = "test", items = items })
  end

  it("starts with no flags and toggles them on/off", function()
    local h = open({
      { key = "a", arg = true, flag = "--all", label = "all" },
      { key = "n", arg = true, flag = "--allow-new", label = "new" },
      { key = "p", label = "push", run = function() end },
    })
    assert.same({}, h.flags())
    h.toggle("a")
    assert.same({ "--all" }, h.flags())
    h.toggle("n")
    assert.same({ "--all", "--allow-new" }, h.flags()) -- item order preserved
    h.toggle("a")
    assert.same({ "--allow-new" }, h.flags())
    h.close()
  end)

  it("renders a checkbox that reflects the toggle state", function()
    local h = open({
      { key = "n", arg = true, flag = "--allow-new", label = "allow new bookmarks" },
      { key = "p", label = "push tracked", run = function() end },
    })
    local function argline()
      for _, l in ipairs(vim.api.nvim_buf_get_lines(h.buf, 0, -1, false)) do
        if l:find("allow new bookmarks", 1, true) then
          return l
        end
      end
    end
    assert.is_truthy(argline():find("[ ]", 1, true), "starts unchecked")
    h.toggle("n")
    assert.is_truthy(argline():find("[✓]", 1, true), "checked after toggle")
    h.close()
  end)

  it("passes the enabled flags to an action's run()", function()
    local got
    local h = open({
      { key = "n", arg = true, flag = "--allow-new", label = "new" },
      {
        key = "p",
        label = "push",
        run = function(flags)
          got = flags
        end,
      },
    })
    h.toggle("n")
    -- fire the action's buffer-local mapping exactly as a keypress would
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(h.buf, "n")) do
      if m.lhs == "p" and m.callback then
        m.callback()
      end
    end
    assert.is_true(
      vim.wait(500, function()
        return got ~= nil
      end, 10),
      "run() should fire"
    )
    assert.same({ "--allow-new" }, got)
  end)

  it("value args contribute flag + value, compose with booleans, and clear", function()
    local h = open({
      { key = "d", arg = true, flag = "--dry-run", label = "dry run" },
      { key = "r", arg = true, value = true, flag = "--remote", label = "remote" },
      { key = "p", label = "push", run = function() end },
    })
    assert.same({}, h.flags())
    h.setval("r", "origin")
    assert.same({ "--remote", "origin" }, h.flags())
    h.toggle("d")
    assert.same({ "--dry-run", "--remote", "origin" }, h.flags()) -- item order preserved
    h.setval("r", "") -- empty clears the value arg
    assert.same({ "--dry-run" }, h.flags())
    h.close()
  end)

  it("renders a value arg as [=val]", function()
    local h = open({
      { key = "r", arg = true, value = true, flag = "--remote", label = "remote" },
      { key = "p", label = "push", run = function() end },
    })
    local function argline()
      for _, l in ipairs(vim.api.nvim_buf_get_lines(h.buf, 0, -1, false)) do
        if l:find("remote", 1, true) then
          return l
        end
      end
    end
    assert.is_truthy(argline():find("[ ]", 1, true), "empty value shows [ ]")
    h.setval("r", "upstream")
    assert.is_truthy(argline():find("[=upstream]", 1, true), "set value shows [=upstream]")
    h.close()
  end)

  it("a pre-set val renders and contributes immediately (menu reflects state)", function()
    -- The op-log options menu re-opens with the active --limit pre-filled.
    local h = open({
      { key = "n", arg = true, value = true, flag = "--limit", label = "limit", val = "4" },
      { key = "a", label = "apply", run = function() end },
    })
    assert.same({ "--limit", "4" }, h.flags())
    local shown = table.concat(vim.api.nvim_buf_get_lines(h.buf, 0, -1, false), "\n")
    assert.is_truthy(shown:find("[=4]", 1, true), "pre-set value shows [=4]")
    h.close()
  end)
end)
