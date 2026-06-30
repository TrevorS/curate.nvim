-- Unit + integration tests for the data layer (template parser, diff parser).

local template = require("curate.jj.template")
local diff = require("curate.jj.diff")
local H = require("spec.helpers.jj_repo")

describe("template.parse_log", function()
  local US, RS = template.US, template.RS

  local function rec(fields)
    return table.concat(fields, US) .. RS
  end

  it("parses one record into a typed Change", function()
    local raw = rec({
      "kkmpptxz",
      "abc12345",
      "a@b.com",
      "2 minutes ago",
      "feat: thing",
      "parent1 parent2",
      "I@",
    })
    local out = template.parse_log(raw)
    assert.equals(1, #out)
    local c = out[1]
    assert.equals("kkmpptxz", c.id)
    assert.equals("abc12345", c.commit)
    assert.equals("a@b.com", c.email)
    assert.equals("feat: thing", c.subject)
    assert.same({ "parent1", "parent2" }, c.parents)
    assert.is_true(c.flags.immutable)
    assert.is_true(c.flags.current)
    assert.is_false(c.flags.conflict)
  end)

  it("handles empty fields and the blank tail after the final RS", function()
    local raw = rec({ "rootroot", "00000000", "", "56 years ago", "", "", "I" })
    local out = template.parse_log(raw)
    assert.equals(1, #out)
    assert.equals("", out[1].subject)
    assert.same({}, out[1].parents)
    assert.is_true(out[1].flags.immutable)
  end)

  it("parses multiple records", function()
    local raw = rec({ "aaaa", "1", "x@y", "now", "a", "", "@" })
      .. rec({ "bbbb", "2", "x@y", "1m", "b", "aaaa", "" })
    local out = template.parse_log(raw)
    assert.equals(2, #out)
    assert.equals("aaaa", out[1].id)
    assert.same({ "aaaa" }, out[2].parents)
  end)
end)

describe("diff.parse", function()
  it("splits files and hunks with add/remove counts", function()
    local text = table.concat({
      "diff --git a/a.txt b/a.txt",
      "index ce..2b 100644",
      "--- a/a.txt",
      "+++ b/a.txt",
      "@@ -1,1 +1,2 @@",
      " hello",
      "+more",
      "diff --git a/b.txt b/b.txt",
      "new file mode 100644",
      "--- /dev/null",
      "+++ b/b.txt",
      "@@ -0,0 +1,1 @@",
      "+world",
    }, "\n")
    local files = diff.parse(text)
    assert.equals(2, #files)
    assert.equals("a.txt", files[1].path)
    assert.equals("M", files[1].status)
    assert.equals(1, #files[1].hunks)
    assert.equals(1, files[1].added)
    assert.equals(0, files[1].removed)
    assert.equals(1, files[1].hunks[1].old_start)
    assert.equals(2, files[1].hunks[1].new_count)
    assert.equals("A", files[2].status)
    assert.equals(2, diff.hunk_count(files))
  end)

  it("flags binary files", function()
    local text = table.concat({
      "diff --git a/img.png b/img.png",
      "Binary files a/img.png and b/img.png differ",
    }, "\n")
    local files = diff.parse(text)
    assert.equals(1, #files)
    assert.is_true(files[1].binary)
  end)
end)

describe("integration: template against real jj", function()
  if not H.has_jj() then
    pending("jj not installed")
    return
  end

  it("renders a real repo into Change records", function()
    local dir = H.make()
    H.write(dir, "a.txt", "hello\n")
    H.jj(dir, { "describe", "-m", "first" })
    H.jj(dir, { "new", "-m", "second" })
    H.write(dir, "b.txt", "world\n")

    local r = vim
      .system(
        vim.list_extend({ "jj", "--no-pager", "--color=never" }, template.log_args("all()")),
        { cwd = dir, env = H.env(), text = true }
      )
      :wait()
    assert.equals(0, r.code)
    local changes = template.parse_log(r.stdout)
    -- root + first + second = at least 3
    assert.is_true(#changes >= 3)
    -- exactly one working-copy change
    local current = vim.tbl_filter(function(c)
      return c.flags.current
    end, changes)
    assert.equals(1, #current)
    -- the root commit is immutable
    local immutable = vim.tbl_filter(function(c)
      return c.flags.immutable
    end, changes)
    assert.is_true(#immutable >= 1)
  end)
end)
