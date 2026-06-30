-- curate.nvim — jj's working copy is already a commit; curate is the one tool
-- for turning it into the commit you meant.
--
-- Public API. `require("curate").setup(opts)` is the only entry users call.

local M = {}

M.version = "0.1.0"

---@param opts table|nil
function M.setup(opts)
  require("curate.config").apply(opts or {})
  require("curate.ui.highlights").setup()
  require("curate.keymap").install()

  -- Re-apply highlight links after a colorscheme change.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("curate.colors", { clear = true }),
    callback = function()
      require("curate.ui.highlights").setup()
    end,
  })
end

--- Open the home (status) view. Convenience for `require("curate").status()`.
function M.status()
  require("curate.views.status").open()
end

function M.log()
  require("curate.views.log").open()
end

function M.oplog()
  require("curate.views.oplog").open()
end

return M
