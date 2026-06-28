-- CSV/TSV <-> markdown-table conversion (lightweight; no large-file editing).
-- Parsing is RFC 4180-ish: "-quoted fields, "" escapes, delimiter/newline inside
-- quotes. Conversion reuses grid widths via format.build_lines.
local width = require('pipetable.width')
local format = require('pipetable.format')

local M = {}

---Guess the delimiter from the first record (tab / comma / semicolon).
---@param text string
---@return string
function M.detect_delim(text)
  local line = text:match('^[^\r\n]*') or ''
  local best, bestn = ',', 0 -- default to comma; only a positive count overrides
  for _, d in ipairs({ '\t', ',', ';' }) do
    local n = 0
    for _ in line:gmatch(d == '\t' and '\t' or ('%' .. d)) do
      n = n + 1
    end
    if n > bestn then
      best, bestn = d, n
    end
  end
  return best
end

---Parse CSV/TSV text into a 2D array of rows of field strings.
---@param text string
---@param delim string|nil
---@return string[][] rows, string delim
function M.parse(text, delim)
  delim = delim or M.detect_delim(text)
  local rows, row, field = {}, {}, {}
  local in_q = false
  local i, n = 1, #text
  local function end_field()
    row[#row + 1] = table.concat(field)
    field = {}
  end
  local function end_row()
    end_field()
    rows[#rows + 1] = row
    row = {}
  end
  while i <= n do
    local c = text:sub(i, i)
    if in_q then
      if c == '"' then
        if text:sub(i + 1, i + 1) == '"' then
          field[#field + 1] = '"'
          i = i + 2
        else
          in_q = false
          i = i + 1
        end
      else
        field[#field + 1] = c
        i = i + 1
      end
    elseif c == '"' then
      in_q = true
      i = i + 1
    elseif c == delim then
      end_field()
      i = i + 1
    elseif c == '\r' then
      i = (text:sub(i + 1, i + 1) == '\n') and i + 2 or i + 1
      end_row()
    elseif c == '\n' then
      end_row()
      i = i + 1
    else
      field[#field + 1] = c
      i = i + 1
    end
  end
  if #field > 0 or #row > 0 then
    end_row()
  end
  return rows, delim
end

---Serialize a 2D array of rows to CSV/TSV text (quoting as needed).
---@param rows string[][]
---@param delim string|nil
---@return string
function M.to_csv(rows, delim)
  delim = delim or ','
  local dclass = (delim == '\t') and '\t' or delim
  local function q(s)
    if s:find('[' .. dclass .. '"\r\n]') then
      return '"' .. s:gsub('"', '""') .. '"'
    end
    return s
  end
  local out = {}
  for _, r in ipairs(rows) do
    local fs = {}
    for _, f in ipairs(r) do
      fs[#fs + 1] = q(f)
    end
    out[#out + 1] = table.concat(fs, delim)
  end
  return table.concat(out, '\n')
end

---CSV/TSV text -> aligned markdown table lines (first record = header).
---@param text string
---@param delim string|nil
---@return string[]|nil
function M.to_markdown(text, delim)
  local rows = M.parse(text, delim)
  -- drop fully-empty records (e.g. trailing blank lines)
  rows = vim.tbl_filter(function(r)
    return not (#r == 0 or (#r == 1 and r[1] == ''))
  end, rows)
  if #rows == 0 then
    return nil
  end
  local ncols = 0
  for _, r in ipairs(rows) do
    ncols = math.max(ncols, #r)
  end
  local cells = {}
  for ri, r in ipairs(rows) do
    cells[ri] = {}
    for c = 1, ncols do
      -- markdown cells are single-line; escape pipes and flatten newlines
      cells[ri][c] = width.escape_pipe(((r[c] or ''):gsub('[\r\n]+', ' ')))
    end
  end
  local align = {}
  for c = 1, ncols do
    align[c] = 'default'
  end
  return format.build_lines({ cells = cells, align = align, nrows = #rows, ncols = ncols })
end

---Parsed markdown table -> CSV/TSV text.
---@param tbl table parsed Table
---@param delim string|nil
---@return string
function M.from_markdown(tbl, delim)
  local rows = {}
  for _, row in ipairs(tbl.rows) do
    local r = {}
    for c = 1, tbl.ncols do
      local cell = row.cells[c]
      r[c] = width.unescape_pipe(cell and cell.text or '')
    end
    rows[#rows + 1] = r
  end
  return M.to_csv(rows, delim)
end

return M
