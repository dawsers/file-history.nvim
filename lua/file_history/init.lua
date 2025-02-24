local has_snacks_picker, snacks_picker = pcall(require, "snacks.picker")
if not has_snacks_picker then
  error("This plugin requires folke/snacks.nvim")
end

local fh = require("file_history.fh")
local actions = require("file_history.actions")

-- Set default values for highlighting groups
vim.cmd("highlight default link FileHistoryTime Number")
vim.cmd("highlight default link FileHistoryDate Function")
vim.cmd("highlight default link FileHistoryFile Keyword")
vim.cmd("highlight default link FileHistoryTag Comment")

local M = {}

local defaults = {
  -- This is the location where it will create your file history repository
  backup_dir = "~/.file-history-git",
  -- command line to execute git
  git_cmd = "git"
}


local function str_prepare(str, len)
  local s
  if #str > len then
    s = string.sub(str, 1, len)
  else
    s = str
  end
  local format = "%-" .. tostring(len) .. "s"
  return string.format(format, s)
end

local function split(str, sep)
  local result = {}
  for field in string.gmatch(str, ("[^%s]+"):format(sep)) do
    table.insert(result, field)
  end
  return result
end

local function preview_file_history(ctx, data)
  if data.log ~= ctx.item.log then
    if data.log == true then
      ctx.item.diff = table.concat(fh.get_log(ctx.item.file, ctx.item.hash), '\n')
      ctx.item.log = true
    else
      if not data.buf_lines then
        return
      end
      local parent_lines = fh.get_file(ctx.item.file, ctx.item.hash)
      ctx.item.diff = vim.diff(table.concat(data.buf_lines, '\n'), table.concat(parent_lines, '\n'), { result_type = 'unified', ctxlen = 3 })
      ctx.item.log = false
    end
  end
  snacks_picker.preview.diff(ctx)
end

local function preview_file_query(ctx, data)
  if data.log ~= ctx.item.log then
    if data.log == true then
      ctx.item.diff = table.concat(fh.get_log(ctx.item.file, ctx.item.hash), '\n')
      ctx.item.log = true
    else
      local lines = fh.get_file(ctx.item.file, "HEAD")
      local parent_lines = fh.get_file(ctx.item.file, ctx.item.hash)
      ctx.item.diff = vim.diff(table.concat(lines, '\n'), table.concat(parent_lines, '\n'), { result_type = 'unified', ctxlen = 3 })
      ctx.item.log = false
    end
  end
  snacks_picker.preview.diff(ctx)
end

local function file_history_finder(_)
  local entries = vim.iter(fh.file_history()):flatten():totable()
  local results = {}
  for _, entry in pairs(entries) do
    if entry and entry ~= "" then
      local fields = split(entry, '\x09')
      local result = {
        time = fields[1],
        date = fields[2],
        hash = fields[3],
        file = fields[4],
        tag = fields[5] or ''
      }
      result.text = result.tag .. ' ' .. result.time .. ' ' .. result.date
      table.insert(results, result)
    end
  end
  return results
end

local function file_history_files_finder(_)
  local entries = vim.iter(fh.file_history_files()):flatten():totable()
  if #entries == 0 then
    return {}
  end
  local hostname = vim.fn.hostname()
  local results = {}
  for _, entry in pairs(entries) do
    if entry and entry ~= "" then
      local result = {}
      local index = string.find(entry, '/')
      if index then
        -- If file is local, enable preview
        if hostname == string.sub(entry, 1, index - 1) then
          result.file = string.sub(entry, index)
          result.text = result.file
        else
          result.file = nil
          result.text = entry
        end
        -- This is the name, or reference for deleting/purging etc
        result.name = entry
        result.hash = "HEAD"
        table.insert(results, result)
      end
    end
  end
  return results
end

local function file_history_query_finder(after, before)
  local entries = vim.iter(fh.file_history_query(after, before)):flatten():totable()
  local results = {}
  for _, entry in pairs(entries) do
    if entry and entry ~= "" then
      local fields = split(entry, '\x09')
      local result = {
        date = fields[1],
        hash = fields[2],
        file = fields[3],
        tag = fields[4] or ''
      }
      result.text = result.date .. ' ' .. result.tag .. ' ' .. result.file
      table.insert(results, result)
    end
  end
  return results
end

local function file_history_picker(data)
  local fhp = {}
  fhp.win = {
    title = "FileHistory history",
    input = {
      keys = {
        ["<M-d>"] = { "open_buffer_diff_tab", desc = "Open diff in new tab", mode = { "n", "i" } },
        ["<C-r>"] = { "revert_to_selected", desc = "Revert current buffer to selected commit", mode = { "n", "i" } },
        ["<M-l>"] = { "toggle_incremental", desc = "Toggle incremental diff mode", mode = { "n", "i" } },
      }
    }
  }
  fhp.finder = file_history_finder
  fhp.format = function(item)
    local ret = {}
    ret[#ret + 1] = { str_prepare(item.time or "", 16), "FileHistoryTime" }
    ret[#ret + 1] = { " " }
    ret[#ret + 1] = { str_prepare(item.date or "", 32), "FileHistoryDate" }
    ret[#ret + 1] = { " " }
    ret[#ret + 1] = { item.tag or "", "FileHistoryTag" }
    return ret
  end
  fhp.preview = function(ctx) preview_file_history(ctx, data) end
  fhp.actions = {
    open_buffer_diff_tab = function(_, item)
      actions.open_buffer_diff_tab(item, data)
    end,
    revert_to_selected = function(picker, item)
      actions.revert_to_selected(item, data)
      picker:close()
    end,
    toggle_incremental = function(picker, _)
      data.log = not data.log
      picker.preview:refresh(picker)
    end
  }
  fhp.confirm = function(_, item)
    actions.open_selected_hash_in_new_tab(item, data)
  end
  return fhp
end

local function file_history_files_picker()
  local fhp = {}
  fhp.win = {
    title = "FileHistory files",
    input = {
      keys = {
        ["<M-d>"] = { "delete_history", desc = "Delete file's history", mode = { "n", "i" } },
        ["<M-p>"] = { "purge_history", desc = "Purge file's history", mode = { "n", "i" } },
      }
    }
  }
  fhp.finder = file_history_files_finder
  fhp.format = function(item)
    local ret = {}
    ret[#ret + 1] = { item.text or "", "FileHistoryFile" }
    return ret
  end
  fhp.preview = function(ctx)
    if ctx.item.file and vim.uv.fs_stat(ctx.item.file) then
      snacks_picker.preview.file(ctx)
    else
      ctx.preview:reset()
    end
  end
  fhp.actions = {
    delete_history = function(picker, _)
      actions.delete_history(picker)
      picker:close()
    end,
    purge_history = function(picker, _)
      actions.purge_history(picker)
      picker:close()
    end
  }
  fhp.confirm = function(_, item)
    actions.open_selected_file_hash_in_new_tab(item)
  end
  return fhp
end

local function prepare_picker_data()
  local data = {
    buf = nil,
    buf_lines = nil,
    log = false,
  }
  -- Stores the current editor buffer and its lines to diff in previews
  data.buf = vim.api.nvim_get_current_buf()
  data.buf_lines = vim.api.nvim_buf_get_lines(data.buf, 0, -1, true)
  return data
end

function M.history()
  local data = prepare_picker_data()
  snacks_picker.pick(file_history_picker(data))
end

function M.files()
  snacks_picker.pick(file_history_files_picker())
end

function M.backup()
  vim.ui.input({ prompt = "Tag name: " }, function(tag)
    if tag then
      fh.set_tag(tag)
    end
    vim.cmd({ cmd = "write" })
  end)
end

function M.query()
  local data = { log = false }
  vim.ui.input({ prompt = "After: " }, function(after)
    vim.ui.input({ prompt = "Before: " }, function(before)
      local fhp = {}
      fhp.win = {
          title = "FileHistory query",
          input = {
            keys = {
              ["<M-d>"] = { "open_file_diff_tab", desc = "Open diff in new tab", mode = { "n", "i" } },
              ["<M-l>"] = { "toggle_incremental", desc = "Toggle incremental diff mode", mode = { "n", "i" } },
            }
          }
      }
      fhp.items = file_history_query_finder(after, before)
      fhp.format = function(item)
        local ret = {}
        ret[#ret + 1] = { str_prepare(item.date or "", 32), "FileHistoryDate" }
        ret[#ret + 1] = { " " }
        ret[#ret + 1] = { str_prepare(item.tag or "", 24), "FileHistoryTag" }
        ret[#ret + 1] = { " " }
        ret[#ret + 1] = { item.file or "", "FileHistoryFile" }
        return ret
      end
      fhp.preview = function(ctx)
        if ctx.item.file and vim.uv.fs_stat(ctx.item.file) then
          preview_file_query(ctx, data)
        else
          ctx.preview:reset()
        end
      end
      fhp.actions = {
        open_file_diff_tab = function(_, item)
          actions.open_file_diff_tab(item)
        end,
        toggle_incremental = function(picker, _)
          data.log = not data.log
          picker.preview:refresh(picker)
        end
      }
      fhp.confirm = function(_, item)
        actions.open_selected_file_hash_in_new_tab(item)
      end
      -- Call the picker
      snacks_picker.pick(fhp)
    end)
  end)
end

local function commands(args)
  if args.fargs[1] == "history" then
    M.history()
  elseif args.fargs[1] == "files" then
    M.files()
  elseif args.fargs[1] == "backup" then
    M.backup()
  elseif args.fargs[1] == "query" then
    M.query()
  end
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", defaults, opts or {})
  fh.setup(opts)

  vim.api.nvim_create_user_command("FileHistory", commands, { nargs = 1 })
end

return M
