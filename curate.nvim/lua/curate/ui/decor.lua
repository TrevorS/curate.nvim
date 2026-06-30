-- ui/decor.lua — live, transient highlight via a decoration provider.
--
-- The rebase/squash destination tracking your cursor never rewrites the buffer;
-- it is painted per-redraw with `ephemeral` extmarks. State lives per-buffer so
-- there are no module-level globals leaking across views. (§F.)

local M = {}

-- buf -> { dest = change_id, row2id = { [row] = change_id } }
M.state = {}

local ns = vim.api.nvim_create_namespace("curate.decor")

vim.api.nvim_set_decoration_provider(ns, {
  on_line = function(_, _, buf, row)
    local st = M.state[buf]
    if not st or not st.dest then
      return
    end
    if st.row2id[row] == st.dest then
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        line_hl_group = "CurateRebaseDest",
        ephemeral = true, -- key: per-draw, never persisted
      })
    end
  end,
})

--- Register the row -> change-id map for a buffer (called on each render).
---@param buf integer
---@param row2id table<integer,string>
function M.bind(buf, row2id)
  M.state[buf] = M.state[buf] or {}
  M.state[buf].row2id = row2id
end

--- Mark a destination change and repaint.
---@param buf integer
---@param id string|nil
function M.set_dest(buf, id)
  M.state[buf] = M.state[buf] or { row2id = {} }
  M.state[buf].dest = id
  vim.cmd.redraw()
end

--- Forget a buffer's decor state (on close).
---@param buf integer
function M.clear(buf)
  M.state[buf] = nil
end

return M
