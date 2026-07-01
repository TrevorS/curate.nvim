-- :checkhealth curate — drive M.check() with a stubbed vim.health and assert it
-- reports on the pieces we care about (here: the treesitter parser section).

local health = require("curate.health")

describe("health.check", function()
  -- Capture every h.<level>(msg) call as { level, msg }.
  local function run(opts)
    require("curate.config").apply(opts or {})
    local log = {}
    local real = vim.health
    vim.health = setmetatable({}, {
      __index = function(_, level)
        return function(msg)
          log[#log + 1] = { level = level, msg = msg }
        end
      end,
    })
    local ok, err = pcall(health.check)
    vim.health = real
    assert(ok, err)
    return log
  end

  local function find(log, pattern)
    for _, e in ipairs(log) do
      if type(e.msg) == "string" and e.msg:match(pattern) then
        return e
      end
    end
  end

  it("reports installed treesitter parsers when diff_syntax is on", function()
    local log = run({ diff_syntax = true })
    -- lua ships with Neovim, so the parser list should be non-empty here.
    local e = find(log, "treesitter parsers")
    assert.is_truthy(e, "expected a treesitter parser line")
    assert.equals("ok", e.level)
    assert.is_truthy(e.msg:match("lua"))
  end)

  it("notes when diff syntax highlighting is disabled", function()
    local e = find(run({ diff_syntax = false }), "diff syntax highlighting disabled")
    assert.is_truthy(e)
    assert.equals("info", e.level)
  end)
end)
