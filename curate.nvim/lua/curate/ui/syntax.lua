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

--- Highlight spans for a whole file, parsed as one tree so multi-line
--- constructs (block strings/comments, and every node's surrounding context)
--- resolve correctly — this is the "proper", not per-line, path. Injected
--- languages are highlighted in their own language too (vimscript in
--- `vim.cmd[[...]]`, fenced code in markdown, …). Multi-line nodes are split
--- into one span per row they cover. Returns a 1-based row -> spans map so a
--- caller can project them onto its own rows by line number.
---@param lines string[]
---@param lang string|nil
---@return table<integer, curate.Span[]>  row -> { {group, start_col, end_col}, ... } (byte cols)
function M.buffer_spans(lines, lang)
  if not lang or #lines == 0 then
    return {}
  end
  local src = table.concat(lines, "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, lang)
  if not ok or not parser then
    return {}
  end
  pcall(parser.parse, parser, true) -- parse WITH injections

  local by_row = {}
  -- Captures arrive in query order; more specific captures come later, so we
  -- keep them in order and let the caller's later extmarks win per attribute.
  local function push(row, group, s, e)
    if e > s then
      by_row[row] = by_row[row] or {}
      by_row[row][#by_row[row] + 1] = { group, s, e }
    end
  end
  local function collect(tree, tlang)
    local query = highlights_query(tlang)
    if not query then
      return
    end
    for id, node in query:iter_captures(tree:root(), src, 0, -1) do
      local group = "@" .. query.captures[id]
      local srow, scol, erow, ecol = node:range()
      if srow == erow then
        push(srow + 1, group, scol, ecol)
      else
        -- e.g. a [[ long string ]] or block comment: paint each covered row.
        for r = srow, erow do
          local s = (r == srow) and scol or 0
          local e = (r == erow) and ecol or #(lines[r + 1] or "")
          push(r + 1, group, s, e)
        end
      end
    end
  end
  local function member(lt, method)
    local okm, v = pcall(lt[method], lt)
    return okm and v or {}
  end
  -- Primary language first, then injected children — children lay later so
  -- their language wins on the overlapping host node (vim over the lua string).
  local function walk(lt)
    for _, tree in pairs(member(lt, "trees")) do
      pcall(collect, tree, lt:lang())
    end
    for _, child in pairs(member(lt, "children")) do
      walk(child)
    end
  end
  pcall(walk, parser)
  return by_row
end

--- Highlight spans for a single standalone line (thin wrapper over buffer_spans;
--- used where there is no surrounding file to parse).
---@param code string
---@param lang string|nil
---@return curate.Span[]  {group, start_col, end_col} byte cols
function M.spans(code, lang)
  if code == "" then
    return {}
  end
  return M.buffer_spans({ code }, lang)[1] or {}
end

return M
