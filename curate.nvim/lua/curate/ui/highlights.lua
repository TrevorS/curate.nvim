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
  -- Diff/state groups below are painted on TEXT spans, so they link to
  -- foreground-based groups (Added/Removed/DiagnosticError). Modern
  -- colorschemes (catppuccin, tokyonight, …) make DiffAdd/DiffDelete
  -- background-only, which would leave this text in the default fg.
  CurateConflict = "DiagnosticError", -- ✗ markers / conflict counts (red fg)
  CurateDivergent = "WarningMsg",
  CurateEmpty = "Comment",
  CurateFile = "Directory",
  CurateHunkHeader = "Function",
  CurateAdded = "Added", -- + diff lines, +N counts (green fg)
  CurateRemoved = "Removed", -- - diff lines, -N counts (red fg)
  -- Line-background tints for diff rows that also carry syntax highlighting:
  -- DiffAdd/DiffDelete are the background-based groups (bg-only under modern
  -- themes), so treesitter foreground colors stay legible on top.
  CurateAddedLine = "DiffAdd",
  CurateRemovedLine = "DiffDelete",
  -- Stronger background for the exact tokens that changed within a modified
  -- line (intra-line / word diff). DiffText is the standard "changed region"
  -- group; bg-only under modern themes, so syntax foreground survives.
  CurateAddedText = "DiffText",
  CurateRemovedText = "DiffText",
  CurateContext = "Comment",
  CurateSelected = "Added", -- chosen side / selected hunk (green fg)
  CurateDeselected = "Comment",
  CurateRebaseDest = "Visual", -- a true line background (decoration provider)
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
