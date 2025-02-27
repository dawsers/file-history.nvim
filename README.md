# file-history.nvim

## Introduction

[file-history.nvim](https://github.com/dawsers/file-history.nvim) provides
local history backup for all the files you edit. Every time you save a file
it is kept in an internal git repository. You can query this repository and
go back to any file at any point in time using the provided pickers. The
pickers use Neovim's [snacks.nvim](https://github.com/folke/snacks.nvim).

The goal of the extension is to have a history of the changes you make to
your files, with less granularity than `undo`, which is sometimes too much, but
more than what you would normally *commit* to a versioning repository. And it
also supports files that are not in any project or repo.


## Requirements

File backups work without [snacks.nvim](https://github.com/folke/snacks.nvim),
but you will need it be able to view and manage the files saved by this plugin.

[git](https://git-scm.com) is also a hard requirement to create and manage
the file history repository.

If you want to use the action to completely remove a file from the
repository (`purge`) instead of (`delete`), the extension has an additional
dependency: [git-filter-repo](https://github.com/newren/git-filter-repo).
`git filter-branch` is not reliable and quick enough, so I decided to add
this dependency. The plugin will still work without it, but `purge` won't
do anything.


## Installation and Configuration

There are no default keymaps, but there are default settings for the
highlighting groups in case you don't want to add them to your theme.

If you use [lazy.nvim](https://github.com/folke/lazy.nvim), configuring the
plugin could look like this:

``` lua
{
  'dawsers/file-history.nvim',
  config = function()
    local file_history = require('file_history')
    file_history.setup({
      -- These are the default values, change them if needed
      -- Location where the plugin will create your file history repository
      backup_dir = "~/.file-history-git",
      -- command line to execute git
      git_cmd = "git"
      -- If you want to override the automatic query for hostname, change this
      -- option. By default (nil), the plugin gets the host name for the computer
      -- it is running on.
      --
      -- You should only modify this value if you understand the following:
      -- This plugin writes a backup copy of every file you edit in neovim, not
      -- just your coding projects. When copying the file-history repository from
      -- one computer to another, having the hostname added to each file in the
      -- repo prevents you from messing the history of files that should be unique
      -- to that computer (host). For example, configuration and system files
      -- will probably be different in part or fully. So, even though it may
      -- make sense for coding projects to be able to move the database and
      -- disregard the host name, in many cases you will be editing other types
      -- of files, where keeping the correct host name will help you recover
      -- from mistakes.
      hostname = nil
    })
    -- There are no default key maps, this is an example
    vim.keymap.set('n', '<leader>Bb',function() file_history.backup() end, { silent = true, desc = 'named backup for file' })
    vim.keymap.set('n', '<leader>Bh', function() file_history.history() end, { silent = true, desc = 'local history of file' })
    vim.keymap.set('n', '<leader>Bf', function() file_history.files() end, { silent = true, desc = 'local history files in repo' })
    vim.keymap.set('n', '<leader>Bq', function() file_history.query() end, { silent = true, desc = 'local history query' })
  end
}
```


## Commands

| **Command**                        | **Description**                         |
|------------------------------------|-----------------------------------------|
| `FileHistory backup`               | Force file backup (possibly with a tag) |
| `FileHistory history`              | View the file's history                 |
| `FileHistory files`                | View every file in the repo             |
| `FileHistory query`                | Query the repo                          |

There are no default mappings for any of the commands.

The plugin supports multiple selections.

### Backup

`file-history.nvim` creates automatic backups every time you save a file. But
sometimes you may want to add a `tag` to one of these backups to add some
specific information. `backup` asks for a tag name, which can be anything,
and will store the commit with that name. Using `history` you will be able to
see and search these *tags*.

### History

This command opens a picker with the saved history for the current file. You
can search for a specific version by date or tag while seeing the diff in the
preview panel.

This picker supports four plugin-specific key bindings:

```
<CR>        Opens the selected version of the file in a new tab.
<M-d>       Opens a diff of the selection with the current buffer in a new tab
<C-r>       Reverts the current buffer to the selected commit version
<M-l>       Toggles between incremental and absolute diff mode
```

Incremental diff mode shows the differences between contiguous commits.
Absolute mode shows all the differences between the selected version and the
buffer in the editor.

### Files

Displays all the files in the file history repository, with a preview of
the current state of the file if it still exists. You can use this command
to explore the backup repository, open files, or do some cleanup, removing
them from the backup history for space or privacy reasons.

The plugin supports these additional key bindings:

```
<CR>        Open the latest known version of the selected file in a new tab
<M-d>       Delete the selected file from the repo
<M-p>       Purge the selected file from the repo
```

### Query

Command to query the file history repository to see what files have been
modified within a time frame, and use the picker to search for specific
versions and recover them if needed. The command will ask for two arguments:
`after` and `before`. You can leave any of them empty.

1. `After`: Query for file modifications happening **after** the specified
   time. For example `2 hours ago` or `2025-02-20 02:23:51`
2. `Before`: Query for file modifications happening **before** the input time,
   same format as `After`

You can use `After`, `Before`, both of them or none.

`query` adds these additional key bindings to the picker:

```
<CR>        Opens the selected version of the file in a new tab.
<M-d>       Opens a diff of the selection with the current buffer in a new tab
<M-l>       Toggles between incremental and absolute diff mode
```


## Highlighting

There are four highlighting groups you can use to customize the look of the
results: `FileHistoryTime`, `FileHistoryDate`, `FileHistoryFile` and
`FileHistoryTag`. You can assign colors to them customizing your *colorscheme*,
or in your Neovim configuration.


``` lua
-- These are the default values for the highlighting groups if you don't
-- modify them
vim.cmd("highlight default link FileHistoryTime Number")
vim.cmd("highlight default link FileHistoryDate Function")
vim.cmd("highlight default link FileHistoryFile Keyword")
vim.cmd("highlight default link FileHistoryTag Comment")

-- You can override them using nvim_set_hl
vim.api.nvim_set_hl(0, "FileHistoryDate", { link = "Number" })
...
```
