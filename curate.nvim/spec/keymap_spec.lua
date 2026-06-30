-- Tests for the keymap registry: every action string must be dispatchable,
-- including underscore-named fns (the bug that silently broke x / S / etc.).

local keymap = require("curate.keymap")

describe("keymap registry", function()
  it("every registered action string parses with the underscore-aware pattern", function()
    for ft, list in pairs(keymap.maps) do
      for _, entry in ipairs(list) do
        local action = entry[2]
        local mod, fn = action:match("^([%w_]+)%.([%w_]+)$")
        assert.is_truthy(mod and fn, "action must parse: " .. action .. " (" .. ft .. ")")
      end
    end
  end)

  it("the actions implemented through P2 resolve to real fns", function()
    local must = {
      "name.new",
      "name.describe",
      "name.commit",
      "route.split_interactive",
      "route.squash_interactive",
      "route.squash",
      "route.restore",
      "trust.undo",
      "trust.oplog",
      "reshape.mark",
      "reshape.rebase",
    }
    for _, action in ipairs(must) do
      local mod, fn = action:match("^([%w_]+)%.([%w_]+)$")
      local m = require("curate.actions." .. mod)
      assert.equals("function", type(m[fn]), "missing: " .. action)
    end
  end)

  it("parses underscore action names that bare %w would drop", function()
    local cases = { "route.split_interactive", "route.squash_interactive", "trust.op_restore_here" }
    for _, a in ipairs(cases) do
      local mod, fn = a:match("^([%w_]+)%.([%w_]+)$")
      assert.is_truthy(mod and fn, "should parse " .. a)
    end
  end)
end)
