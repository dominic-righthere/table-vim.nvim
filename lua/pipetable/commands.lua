-- Global escape hatches: <Plug> mappings (bind your own keys) and :Table*
-- commands (usable outside table mode — they resolve the table at the cursor).
local M = {}

local function buf()
  return vim.api.nvim_get_current_buf()
end

-- delimiter from a command's bang/arg: ! = TSV, arg = explicit ('tab' or a char), else autodetect
local function delim_arg(a)
  if a.bang then
    return '\t'
  end
  if a.args and a.args ~= '' then
    return a.args == 'tab' and '\t' or a.args
  end
  return nil
end

local function replace_lines(b, s0, e0, lines)
  local was = vim.bo[b].modifiable
  vim.bo[b].modifiable = true
  vim.api.nvim_buf_set_lines(b, s0, e0, false, lines)
  vim.bo[b].modifiable = was
  require('pipetable.state').get(b).dirty = true
  require('pipetable.manager').refresh(b)
end

-- name -> action; exposed as <Plug>(pipetable-<name>)
local PLUGS = {
  ['insert-row-below'] = function() require('pipetable.ops').insert_row(buf(), 'below') end,
  ['insert-row-above'] = function() require('pipetable.ops').insert_row(buf(), 'above') end,
  ['insert-col-right'] = function() require('pipetable.ops').insert_col(buf(), 'right') end,
  ['insert-col-left'] = function() require('pipetable.ops').insert_col(buf(), 'left') end,
  ['delete-row'] = function() require('pipetable.ops').delete_row(buf()) end,
  ['delete-col'] = function() require('pipetable.ops').delete_col(buf()) end,
  ['move-row-up'] = function() require('pipetable.ops').move_row(buf(), -1) end,
  ['move-row-down'] = function() require('pipetable.ops').move_row(buf(), 1) end,
  ['move-col-left'] = function() require('pipetable.ops').move_col(buf(), -1) end,
  ['move-col-right'] = function() require('pipetable.ops').move_col(buf(), 1) end,
  ['dup-row'] = function() require('pipetable.ops').dup_row(buf()) end,
  ['dup-col'] = function() require('pipetable.ops').dup_col(buf()) end,
  ['align-left'] = function() require('pipetable.ops').set_align(buf(), 'left') end,
  ['align-center'] = function() require('pipetable.ops').set_align(buf(), 'center') end,
  ['align-right'] = function() require('pipetable.ops').set_align(buf(), 'right') end,
  ['align-default'] = function() require('pipetable.ops').set_align(buf(), 'default') end,
  ['sort-asc'] = function() require('pipetable.ops').sort(buf(), false) end,
  ['sort-desc'] = function() require('pipetable.ops').sort(buf(), true) end,
  ['yank-row'] = function() require('pipetable.ops').yank_row(buf()) end,
  ['paste-below'] = function() require('pipetable.ops').paste(buf(), false) end,
  ['paste-above'] = function() require('pipetable.ops').paste(buf(), true) end,
}

function M.setup()
  for name, fn in pairs(PLUGS) do
    vim.keymap.set('n', '<Plug>(pipetable-' .. name .. ')', fn, { desc = 'pipetable ' .. name })
  end
  -- CSV <Plug> maps (from-csv is visual: it carries the selection range)
  vim.keymap.set('x', '<Plug>(pipetable-from-csv)', ':TableFromCSV<CR>', { desc = 'pipetable from-csv' })
  vim.keymap.set('n', '<Plug>(pipetable-to-csv)', '<Cmd>TableToCSV<CR>', { desc = 'pipetable to-csv' })
  vim.keymap.set('n', '<Plug>(pipetable-paste-csv)', '<Cmd>TablePasteCSV<CR>', { desc = 'pipetable paste-csv' })

  local cmd = vim.api.nvim_create_user_command
  local ops = function() return require('pipetable.ops') end

  cmd('TableInsertRow', function(a) ops().insert_row(buf(), a.bang and 'above' or 'below') end,
    { bang = true, desc = 'pipetable: insert row (! = above)' })
  cmd('TableDeleteRow', function() ops().delete_row(buf()) end, { desc = 'pipetable: delete row' })
  cmd('TableInsertColumn', function(a) ops().insert_col(buf(), a.bang and 'left' or 'right') end,
    { bang = true, desc = 'pipetable: insert column (! = left)' })
  cmd('TableDeleteColumn', function() ops().delete_col(buf()) end, { desc = 'pipetable: delete column' })
  cmd('TableMoveColumn', function(a) ops().move_col(buf(), a.args == 'left' and -1 or 1) end,
    { nargs = 1, complete = function() return { 'left', 'right' } end, desc = 'pipetable: move column' })
  cmd('TableMoveRow', function(a) ops().move_row(buf(), a.args == 'up' and -1 or 1) end,
    { nargs = 1, complete = function() return { 'up', 'down' } end, desc = 'pipetable: move row' })
  cmd('TableAlign', function(a) ops().set_align(buf(), a.args ~= '' and a.args or 'default') end,
    { nargs = 1, complete = function() return { 'left', 'center', 'right', 'default' } end, desc = 'pipetable: set column alignment' })
  cmd('TableSort', function(a) ops().sort(buf(), a.bang) end,
    { bang = true, desc = 'pipetable: sort by current column (! = descending)' })
  cmd('TableYank', function() ops().yank_row(buf()) end, { desc = 'pipetable: yank row' })
  cmd('TablePaste', function(a) ops().paste(buf(), a.bang) end,
    { bang = true, desc = 'pipetable: paste (! = above/left)' })

  -- CSV <-> markdown
  cmd('TableFromCSV', function(a)
    local b = buf()
    local text = table.concat(vim.api.nvim_buf_get_lines(b, a.line1 - 1, a.line2, false), '\n')
    local md = require('pipetable.csv').to_markdown(text, delim_arg(a))
    if not md then
      return vim.notify('pipetable: no CSV rows in range', vim.log.levels.WARN)
    end
    replace_lines(b, a.line1 - 1, a.line2, md)
  end, { range = true, bang = true, nargs = '?', complete = function() return { 'tab', ',', ';' } end,
    desc = 'pipetable: convert CSV/TSV range to a table (! = TSV)' })

  cmd('TableToCSV', function(a)
    local st, tbl = require('pipetable.ops')._resolve(buf())
    if not st or not tbl then
      return vim.notify('pipetable: no table at cursor', vim.log.levels.WARN)
    end
    local text = require('pipetable.csv').from_markdown(tbl, a.bang and '\t' or ',')
    vim.fn.setreg('"', text)
    if require('pipetable.config').get().clipboard then
      pcall(vim.fn.setreg, '+', text)
    end
    vim.notify('pipetable: copied table as ' .. (a.bang and 'TSV' or 'CSV'))
  end, { bang = true, desc = 'pipetable: copy table at cursor as CSV (! = TSV)' })

  cmd('TablePasteCSV', function(a)
    local b = buf()
    local text = vim.fn.getreg('+')
    if text == nil or text == '' then
      text = vim.fn.getreg('"')
    end
    local md = require('pipetable.csv').to_markdown(text, a.bang and '\t' or nil)
    if not md then
      return vim.notify('pipetable: clipboard is not CSV/TSV', vim.log.levels.WARN)
    end
    local row = vim.api.nvim_win_get_cursor(0)[1]
    replace_lines(b, row, row, md) -- insert below the cursor line
  end, { bang = true, desc = 'pipetable: paste clipboard CSV/TSV as a table (! = TSV)' })
end

return M
