-- ui/highlights.lua — define curate's highlight groups, linked to the user's
-- colorscheme so we inherit their palette (Tokyo Night, etc.) for free.

local M = {}

-- group -> default link
local links = {
  CurateChangeId = "Identifier",
  CurateCommitId = "Comment",
  CurateAuthor = "Comment",
  CurateAgo = "Comment",
  CurateSubject = "Normal",
  CurateCurrent = "Title", -- the @ working copy
  CurateImmutable = "Comment", -- ancestors of trunk
  CurateConflict = "DiffDelete",
  CurateDivergent = "WarningMsg",
  CurateEmpty = "Comment",
  CurateFile = "Directory",
  CurateHunkHeader = "Function",
  CurateAdded = "DiffAdd",
  CurateRemoved = "DiffDelete",
  CurateContext = "Comment",
  CurateSelected = "DiffAdd",
  CurateDeselected = "Comment",
  CurateRebaseDest = "Visual",
  CurateOpCurrent = "Title",
  CurateOpId = "Identifier",
  CurateHint = "Comment",
  CurateGraph = "Comment",
}

function M.setup()
  for group, link in pairs(links) do
    -- default = don't clobber a user override; link = inherit colorscheme.
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end
end

return M
