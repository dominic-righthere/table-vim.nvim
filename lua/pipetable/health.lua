-- :checkhealth pipetable
local M = {}

function M.check()
  local health = vim.health
  health.start('pipetable')

  if vim.fn.has('nvim-0.10') == 1 then
    health.ok('Neovim ' .. tostring(vim.version()))
  else
    health.warn('Neovim 0.10+ recommended (extmark conceal / inline virt_text)')
  end

  health.ok('table detection: regex scanner (primary; handles empty-cell rows)')
  local has_md = pcall(vim.treesitter.language.add, 'markdown')
  if has_md then
    health.ok('treesitter `markdown` parser available (fallback detector)')
  else
    health.info('treesitter `markdown` parser not found (only used as a fallback)')
  end

  local ok = pcall(require, 'pipetable.config')
  if ok then
    health.ok('plugin modules load')
  else
    health.error('failed to load pipetable modules')
  end
end

return M
