-- Global escape hatches: <Plug> mappings (bind your own keys) and :Table*
-- commands (usable outside table mode — they resolve the table at the cursor).
local M = {}

local function buf()
  return vim.api.nvim_get_current_buf()
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
end

return M
