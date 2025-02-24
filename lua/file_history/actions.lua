local pfiletype = require "plenary.filetype"
local has_fh, fh = pcall(require, "file_history.fh")
if not has_fh then
  error("Couldn't load file_history module")
end

local fh_actions = {}

fh_actions.revert_to_selected = function(item, data)
  if not data.buf then
    return
  end
  local parent_lines = fh.get_file(item.file, item.hash)
  -- Revert current buffer to selected version
  vim.api.nvim_buf_set_lines(data.buf, 0, -1, true, parent_lines)
end

fh_actions.delete_history = function(picker)
  local items = picker:selected({ fallback = true })
  for _, item in pairs(items) do
    fh.delete_file(item.name)
  end
end

fh_actions.purge_history = function(picker)
  local items = picker:selected({ fallback = true })
  for _, item in pairs(items) do
    fh.purge_file(item.name)
  end
end

fh_actions.open_file_hash_in_new_tab = function(item, filetype)
  local parent_lines = fh.get_file(item.file, item.hash)
  -- Open new tab
  vim.cmd('tabnew')
  -- Diff buffer with selected version
  local nwin = vim.api.nvim_get_current_win()
  local nbufnr = vim.api.nvim_create_buf(true, true)
  local bufname = item.hash .. ':' .. item.file
  vim.api.nvim_buf_set_name(nbufnr, bufname)
  vim.api.nvim_buf_set_option(nbufnr, 'filetype', filetype)
  vim.api.nvim_buf_set_lines(nbufnr, 0, -1, true, parent_lines)
  vim.api.nvim_buf_set_option(nbufnr, 'modifiable', false)
  vim.api.nvim_win_set_buf(nwin, nbufnr)
end

-- Open item's hash in new tab. Item is a version of the current buffer file
fh_actions.open_selected_hash_in_new_tab = function(item, data)
  if not data.buf then
    return
  end
  local filetype = vim.api.nvim_buf_get_option(data.buf, 'filetype')
  fh_actions.open_file_hash_in_new_tab(item, filetype)
end

-- Open item's hash in new tab.
fh_actions.open_selected_file_hash_in_new_tab = function(item)
  local filetype = pfiletype.detect(item.file, {})
  fh_actions.open_file_hash_in_new_tab(item, filetype)
end

local function create_buffer_for_file(file, hash)
  local lines = fh.get_file(file, hash)
  local filetype = pfiletype.detect(file, {})
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_option(buf, 'filetype', filetype)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  return buf
end

-- Open a diff between the buffer and another version of it
fh_actions.open_buffer_diff_tab = function(item, data)
  if not data.buf then
    return
  end
  local pbuf = create_buffer_for_file(item.file, item.hash)
  -- Open new tab
  vim.cmd('tabnew')
  -- Diff buffer with selected version
  local nwin = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(nwin, pbuf)
  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), data.buf)
  -- Diffthis!
  vim.cmd('windo diffthis')
end

-- Open a diff between two versions of a file
fh_actions.open_file_diff_tab = function(item)
  local buf = create_buffer_for_file(item.file, "HEAD")
  local pbuf = create_buffer_for_file(item.file, item.hash)
  -- Open new tab
  vim.cmd('tabnew')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, pbuf)
  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
  -- Diffthis!
  vim.cmd('windo diffthis')
end

return fh_actions

