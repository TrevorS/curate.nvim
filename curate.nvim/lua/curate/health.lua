-- health.lua — :checkhealth curate. Verifies the moving parts of the wedge.

local M = {}

function M.check()
  local h = vim.health
  h.start("curate")

  -- jj present + version
  if vim.fn.executable("jj") == 1 then
    local r = require("curate.jj.runner").sync({ "--version" })
    if r.code == 0 then
      h.ok(vim.trim(r.stdout))
    else
      h.error("`jj --version` failed: " .. (r.stderr or ""))
    end
  else
    h.error("jj not found on PATH")
  end

  -- RPC server (needed for the diff-editor remote-wait)
  if vim.v.servername ~= nil and vim.v.servername ~= "" then
    h.ok("RPC server: " .. vim.v.servername)
  else
    h.warn("no servername yet — the diff-editor will start one on first use")
  end

  -- the wait-shim is on the runtimepath and executable
  local shim = vim.api.nvim_get_runtime_file("bin/curate-diff-shim", false)[1]
  if shim then
    if vim.fn.executable(shim) == 1 then
      h.ok("diff-editor shim: " .. shim)
    else
      h.warn("shim found but not executable: chmod +x " .. shim)
    end
  else
    h.error("bin/curate-diff-shim not found on runtimepath")
  end

  -- nvim version (design targets 0.11+)
  local v = vim.version()
  if v.major > 0 or v.minor >= 11 then
    h.ok(("neovim %d.%d.%d"):format(v.major, v.minor, v.patch))
  else
    h.warn(("neovim %d.%d is older than the 0.11 target"):format(v.major, v.minor))
  end

  -- optional which-key
  if pcall(require, "which-key") then
    h.ok("which-key.nvim detected — keymap labels enabled")
  else
    h.info("which-key.nvim not found (optional)")
  end
end

return M
