-- ui/syntax.lua — per-line treesitter highlight spans, so diff rows can show
-- language colors on the foreground while an add/remove tint lives on the line
-- background. Pure span computation; callers lay the extmarks. Everything is
-- best-effort: no parser for the language → empty spans → caller falls back to
-- flat diff coloring. (Complements ui/highlights.lua; see :help curate-highlights.)

local M = {}

-- Resolved languages and compiled queries are cached; parsing stays per-call
-- (a single short line is cheap and the hunk model has no multi-line node to
-- reuse). false is memoised for "known unavailable" so we don't re-probe.
local lang_cache = {} -- path -> lang|false
local query_cache = {} -- lang -> Query|false

--- Resolve a treesitter language for a file path, or nil when unavailable.
---@param path string
---@return string|nil
function M.lang_for(path)
  if lang_cache[path] ~= nil then
    return lang_cache[path] or nil
  end
  local lang
  local ft = vim.filetype.match({ filename = path })
  if ft then
    lang = vim.treesitter.language.get_lang(ft) or ft
    -- Only accept a language whose parser is actually installed.
    if not pcall(vim.treesitter.language.add, lang) then
      lang = nil
    end
  end
  lang_cache[path] = lang or false
  return lang
end

---@param lang string
---@return vim.treesitter.Query|nil
local function highlights_query(lang)
  if query_cache[lang] ~= nil then
    return query_cache[lang] or nil
  end
  local ok, q = pcall(vim.treesitter.query.get, lang, "highlights")
  query_cache[lang] = (ok and q) or false
  return query_cache[lang] or nil
end

--- Highlight spans for a single line of code.
---@param code string
---@param lang string|nil
---@return { [1]:string, [2]:integer, [3]:integer }[]  {group, start_col, end_col} byte cols
function M.spans(code, lang)
  if not lang or code == "" then
    return {}
  end
  local ok, parser = pcall(vim.treesitter.get_string_parser, code, lang)
  if not ok or not parser then
    return {}
  end
  local query = highlights_query(lang)
  if not query then
    return {}
  end
  local tree = parser:parse()[1]
  if not tree then
    return {}
  end
  local spans = {}
  -- Captures arrive in query order; more specific captures come later, so the
  -- caller lays them in order and lets later extmarks win per attribute.
  for id, node in query:iter_captures(tree:root(), code, 0, -1) do
    local srow, scol, erow, ecol = node:range()
    if srow == 0 and erow == 0 and ecol > scol then
      spans[#spans + 1] = { "@" .. query.captures[id], scol, ecol }
    end
  end
  return spans
end

return M
