-- jj/template.lua — one read query, control-byte separated, into typed tables.
--
-- We never scrape graph glyphs or human output: the graph comes from parent
-- change-ids, computed by us, so a custom theme or glyph set can never break
-- parsing. (§D of the Lua Architecture sketch.)
--
-- NOTE vs the design doc: jj's template language (as of 0.42) accepts \x1f/\x1e
-- byte escapes but NOT \u{1f}. We use the byte escapes — verified against jj
-- 0.42 — which are bytes that cannot occur in the data.

local model = require("curate.jj.model")

local M = {}

local US, RS = "\31", "\30" -- unit / record separator

-- Field order IS the contract between the template and the parser below.
-- Keep these two in lockstep.
M.LOG_T = table.concat({
  "change_id",
  "commit_id.short(8)",
  "author.email()",
  "committer.timestamp().ago()",
  "description.first_line()",
  'parents.map(|c| c.change_id()).join(" ")',
  -- flags packed into one field
  'if(conflict,"C","") ++ if(divergent,"D","") ++ if(immutable,"I","")'
    .. ' ++ if(current_working_copy,"@","") ++ if(empty,"E","")',
}, ' ++ "\\x1f" ++ ') .. ' ++ "\\x1e"'

--- The argv for the one read query. Caller supplies the revset.
---@param revset string
---@return string[]
function M.log_args(revset)
  return { "log", "--no-graph", "-r", revset, "-T", M.LOG_T }
end

---@param flagstr string
---@return curate.ChangeFlags
local function parse_flags(flagstr)
  flagstr = flagstr or ""
  return {
    conflict = flagstr:find("C", 1, true) ~= nil,
    divergent = flagstr:find("D", 1, true) ~= nil,
    immutable = flagstr:find("I", 1, true) ~= nil,
    current = flagstr:find("@", 1, true) ~= nil,
    empty = flagstr:find("E", 1, true) ~= nil,
  }
end

--- Parse the raw stdout of the §1 template query into Change records.
---@param stdout string
---@return curate.Change[]
function M.parse_log(stdout)
  local out = {}
  for rec in vim.gsplit(stdout or "", RS, { plain = true }) do
    -- jj emits no trailing newline structure of its own; skip empties and the
    -- blank tail after the final record separator.
    if vim.trim(rec) ~= "" then
      local f = vim.split(rec, US, { plain = true })
      out[#out + 1] = {
        id = f[1] or "",
        commit = f[2] or "",
        email = f[3] or "",
        ago = f[4] or "",
        subject = f[5] or "",
        parents = vim.split(f[6] or "", " ", { trimempty = true }),
        flags = parse_flags(f[7]),
      }
    end
  end
  return out
end

-- Op-log template: id, timestamp-ago, description first line, current marker.
M.OP_T = table.concat({
  "self.id().short(12)",
  "self.time().end().ago()",
  "self.description()",
  'if(current_operation,"@","")',
}, ' ++ "\\x1f" ++ ') .. ' ++ "\\x1e"'

---@return string[]
function M.oplog_args()
  return { "op", "log", "--no-graph", "-T", M.OP_T }
end

---@param stdout string
---@return curate.Op[]
function M.parse_oplog(stdout)
  local out = {}
  for rec in vim.gsplit(stdout or "", RS, { plain = true }) do
    if vim.trim(rec) ~= "" then
      local f = vim.split(rec, US, { plain = true })
      out[#out + 1] = {
        id = f[1] or "",
        ago = f[2] or "",
        summary = vim.split(f[3] or "", "\n", { plain = true })[1] or "",
        current = (f[4] or ""):find("@", 1, true) ~= nil,
      }
    end
  end
  return out
end

-- Expose for tests / callers that want to round-trip the separators.
M.US, M.RS = US, RS
M.model = model

return M
