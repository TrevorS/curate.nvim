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

  it("every registered action resolves to a real fn (view.* are built-ins)", function()
    -- The full roadmap is shipped, so every non-special action string in the
    -- registry must point at a live actions/ function. Catches typo'd entries.
    local seen = {}
    for _, list in pairs(keymap.maps) do
      for _, entry in ipairs(list) do
        local action = entry[2]
        if not action:match("^view%.") and not seen[action] then
          seen[action] = true
          local mod, fn = action:match("^([%w_]+)%.([%w_]+)$")
          local ok, m = pcall(require, "curate.actions." .. mod)
          assert.is_true(ok, "module must load: curate.actions." .. mod)
          assert.equals("function", type(m[fn]), "missing fn: " .. action)
        end
      end
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
