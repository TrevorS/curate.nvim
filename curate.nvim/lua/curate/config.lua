-- config.lua — defaults + validation. The single source of tunables.

local M = {}

---@class curate.Config
local defaults = {
  -- Revset shown in the log/home view.
  log_revset = require("curate.jj.revset").DEFAULT_LOG,
  -- Debounce (ms) before re-rendering a view after a mutation.
  refresh_debounce = 80,
  -- Where the status/log home opens.
  window = { split = "right", width = 0.45 },
  -- Confirm before rewriting an immutable change.
  confirm_immutable = true,
  -- Name jj sees for our diff-editor (the merge-tool key it invokes).
  diff_editor_name = "curate",
  -- Treesitter-highlight code in the diff/merge editors (add/remove moves to a
  -- line-background tint so syntax colors stay legible). Falls back to flat
  -- green/red when no parser is installed for the language.
  diff_syntax = true,
  -- Emphasise the exact tokens that changed within a modified line (intra-line
  -- word diff) in the diff-editor.
  diff_word = true,
  -- Enable which-key integration if the plugin is installed.
  which_key = true,
}

---@type curate.Config
M.options = vim.deepcopy(defaults)

--- Merge user opts over defaults with light validation.
---@param opts table|nil
function M.apply(opts)
  opts = opts or {}
  vim.validate({
    log_revset = { opts.log_revset, "string", true },
    refresh_debounce = { opts.refresh_debounce, "number", true },
    confirm_immutable = { opts.confirm_immutable, "boolean", true },
    diff_syntax = { opts.diff_syntax, "boolean", true },
    diff_word = { opts.diff_word, "boolean", true },
  })
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  return M.options
end

--- Read a config value by key (used widely so callers don't reach into options).
---@param key string
function M.get(key)
  return M.options[key]
end

return M
