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

  it("never binds j or k — the up/down motions must survive in list views", function()
    -- Users navigate every curate list with j/k; a buffer-local map on either
    -- (with or without nowait) eats the motion. Regression guard for the
    -- k-as-abandon bug: abandon lives on D.
    for ft, list in pairs(keymap.maps) do
      for _, entry in ipairs(list) do
        assert.is_true(entry[1] ~= "j" and entry[1] ~= "k", ft .. " must not bind " .. entry[1])
      end
    end
  end)

  it("does not nowait a key that prefixes longer mappings (g vs g-/g+)", function()
    -- With nowait, typing `g` fires refresh instantly and g-/g+ can never
    -- trigger. install() must disable nowait exactly for such prefix keys.
    keymap.install()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "curate-oplog" -- fires the FileType autocmd
    local by = {}
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      by[m.lhs] = m
    end
    assert.is_truthy(by["g-"], "g- must be mapped in the op-log")
    assert.equals(0, by["g"].nowait, "g must wait so g-/g+ stay reachable")
    assert.equals(1, by["g-"].nowait, "leaf keys stay nowait")
    assert.equals(1, by["q"].nowait, "non-prefix keys stay nowait")
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
