-- lzy/l_nvim-tree

local M = {}

---@type nvim_tree.config
local sample_opts = {
  on_attach = "default",
  hijack_cursor = false,
  auto_reload_on_write = true,
  disable_netrw = false,
  hijack_netrw = true,
  hijack_unnamed_buffer_when_opening = false,
  root_dirs = {},
  prefer_startup_root = false,
  sync_root_with_cwd = false,
  reload_on_bufenter = false,
  respect_buf_cwd = false,
  select_prompts = false,
  sort = {
    sorter = "name",
    folders_first = true,
    files_first = false,
  },
  view = {
    centralize_selection = false,
    cursorline = true,
    cursorlineopt = "both",
    debounce_delay = 15,
    side = "left",
    preserve_window_proportions = false,
    number = false,
    relativenumber = false,
    signcolumn = "yes",
    width = 30,
    float = {
      enable = false,
      quit_on_focus_loss = true,
      open_win_config = {
        relative = "editor",
        border = "rounded",
        width = 30,
        height = 30,
        row = 1,
        col = 1,
      },
    },
  },
  renderer = {
    add_trailing = false,
    group_empty = false,
    full_name = false,
    root_folder_label = ":~:s?$?/..?",
    indent_width = 2,
    special_files = { "Cargo.toml", "Makefile", "README.md", "readme.md" },
    hidden_display = "none",
    symlink_destination = true,
    decorators = {
      "Git",
      "Open",
      "Hidden",
      "Modified",
      "Bookmark",
      "Diagnostics",
      "Copied",
      "Cut",
    },
    highlight_git = "none",
    highlight_diagnostics = "none",
    highlight_opened_files = "none",
    highlight_modified = "none",
    highlight_hidden = "none",
    highlight_bookmarks = "none",
    highlight_clipboard = "name",
    indent_markers = {
      enable = false,
      inline_arrows = true,
      icons = {
        corner = "└",
        edge = "│",
        item = "│",
        bottom = "─",
        none = " ",
      },
    },
    icons = {
      web_devicons = {
        file = {
          enable = true,
          color = true,
        },
        folder = {
          enable = false,
          color = true,
        },
      },
      git_placement = "before",
      modified_placement = "after",
      hidden_placement = "after",
      diagnostics_placement = "signcolumn",
      bookmarks_placement = "signcolumn",
      padding = {
        icon = " ",
        folder_arrow = " ",
      },
      symlink_arrow = " ➛ ",
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = true,
        modified = true,
        hidden = false,
        diagnostics = true,
        bookmarks = true,
      },
      glyphs = {
        default = "",
        symlink = "",
        bookmark = "󰆤",
        modified = "●",
        hidden = "󰜌",
        folder = {
          arrow_closed = "",
          arrow_open = "",
          default = "",
          open = "",
          empty = "",
          empty_open = "",
          symlink = "",
          symlink_open = "",
        },
        git = {
          unstaged = "✗",
          staged = "✓",
          unmerged = "",
          renamed = "➜",
          untracked = "★",
          deleted = "",
          ignored = "◌",
        },
      },
    },
  },
  hijack_directories = {
    enable = true,
    auto_open = true,
  },
  update_focused_file = {
    enable = false,
    update_root = {
      enable = false,
      ignore_list = {},
    },
    exclude = false,
  },
  git = {
    enable = true,
    show_on_dirs = true,
    show_on_open_dirs = true,
    disable_for_dirs = {},
    timeout = 400,
    cygwin_support = false,
  },
  diagnostics = {
    enable = false,
    show_on_dirs = false,
    show_on_open_dirs = true,
    debounce_delay = 500,
    severity = {
      min = vim.diagnostic.severity.HINT,
      max = vim.diagnostic.severity.ERROR,
    },
    icons = {
      hint = "",
      info = "",
      warning = "",
      error = "",
    },
    diagnostic_opts = false,
  },
  modified = {
    enable = false,
    show_on_dirs = true,
    show_on_open_dirs = true,
  },
  filters = {
    enable = true,
    git_ignored = true,
    dotfiles = false,
    git_clean = false,
    no_buffer = false,
    no_bookmark = false,
    custom = {},
    exclude = {},
  },
  live_filter = {
    prefix = "[FILTER]: ",
    always_show_folders = true,
  },
  filesystem_watchers = {
    enable = true,
    debounce_delay = 50,
    max_events = 0,
    ignore_dirs = {
      "/.ccls-cache",
      "/build",
      "/node_modules",
      "/target",
      "/.zig-cache",
    },
    whitelist_dirs = {},
  },
  actions = {
    use_system_clipboard = true,
    change_dir = {
      enable = true,
      global = false,
      restrict_above_cwd = false,
    },
    expand_all = {
      max_folder_discovery = 300,
      exclude = {},
    },
    file_popup = {
      open_win_config = {
        col = 1,
        row = 1,
        relative = "cursor",
        border = "shadow",
        style = "minimal",
      },
    },
    open_file = {
      quit_on_open = false,
      eject = true,
      resize_window = true,
      relative_path = true,
      window_picker = {
        enable = true,
        picker = "default",
        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
        exclude = {
          filetype = {
            "notify",
            "packer",
            "qf",
            "diff",
            "fugitive",
            "fugitiveblame",
          },
          buftype = { "nofile", "terminal", "help" },
        },
      },
    },
    remove_file = {
      close_window = true,
    },
  },
  trash = {
    cmd = "gio trash",
  },
  tab = {
    sync = {
      open = false,
      close = false,
      ignore = {},
    },
  },
  notify = {
    threshold = vim.log.levels.INFO,
    absolute_path = true,
  },
  help = {
    sort_by = "key",
  },
  ui = {
    confirm = {
      remove = true,
      trash = true,
      default_yes = false,
    },
  },
  bookmarks = {
    persist = false,
  },
  experimental = {},
  log = {
    enable = false,
    truncate = false,
    types = {
      all = false,
      config = false,
      copy_paste = false,
      dev = false,
      diagnostics = false,
      git = false,
      profile = false,
      watcher = false,
    },
  },
}
local api = require "nvim-tree.api"

-- Keep nvim-tree at a fixed percentage of the total editor width,
-- but never let it become too narrow to be useful.
function M.resizeTree()
  local percentage = 17
  local min_width = 25
  local ratio = percentage / 100
  local width = math.floor(vim.go.columns * ratio)
  if width < min_width then
    width = min_width
  end

  -- Apply the resize in every tab where nvim-tree is open.
  vim.cmd("tabdo NvimTreeResize " .. width)
end

M.opts = {
  filters = { dotfiles = false },
  disable_netrw = true,
  hijack_cursor = true,

  sync_root_with_cwd = true,
  respect_buf_cwd = true,
  update_focused_file = {
    enable = true,
    update_root = false,
  },

  view = {
    width = 30,
    preserve_window_proportions = true,
    relativenumber = true,
  },
  renderer = {
    root_folder_label = false,
    highlight_git = true,
    indent_markers = { enable = true },
    icons = {
      glyphs = {
        default = "",
        -- default = "󰈚",
        folder = {
          default = "",
          empty = "",
          empty_open = "",
          open = "",
          symlink = "",
        },
        git = { unmerged = "" },
      },
    },
  },
  actions = {
    open_file = {
      window_picker = {
        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
      },
    },
  },

  on_attach = function(bufnr)
    api.config.mappings.default_on_attach(bufnr)

    local lefty = function()
      local node = api.tree.get_node_under_cursor()
      if node and node.nodes and node.open then
        api.node.open.edit()
      else
        api.node.navigate.parent()
      end
    end

    local righty = function()
      local node = api.tree.get_node_under_cursor()
      if node and node.nodes and not node.open then
        api.node.open.edit()
      end
    end

    local mapping_opts = { buffer = bufnr }
    local map = vim.keymap.set
    map("n", "h", lefty, mapping_opts)
    map("n", "<Left>", lefty, mapping_opts)
    map("n", "l", righty, mapping_opts)
    map("n", "<Right>", righty, mapping_opts)
  end,
}

M.setup = function()
  if Snacks then
    local prev = { new_name = "", old_name = "" } -- Prevents duplicate events

    vim.api.nvim_create_autocmd("User", {
      pattern = "NvimTreeSetup",
      callback = function()
        local events = require("nvim-tree.api").events

        events.subscribe(events.Event.NodeRenamed, function(data)
          if prev.new_name ~= data.new_name or prev.old_name ~= data.old_name then
            prev = {
              new_name = data.new_name,
              old_name = data.old_name,
            }

            Snacks.rename.on_rename_file(data.old_name, data.new_name)
          end
        end)
      end,
    })
  end

  ---@diagnostic disable-next-line
  require("nvim-tree").setup(M.opts)

  sabunv.moonfly.setup.nvim_tree()

  vim.api.nvim_create_autocmd({ "VimResized" }, {
    desc = "Resize nvim-tree if nvim window got resized",
    group = vim.api.nvim_create_augroup("NvimTreeResize", { clear = true }),
    callback = M.resizeTree,
  })

  local map = vim.keymap.set
  map("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { desc = "NvimTree: Toggle window" })
  map("n", "<leader>e", "<cmd>NvimTreeFocus<CR>", { desc = "NvimTree: Focus window" })

  -- First Resize
  M.resizeTree()
  sabunv.restart.restore_nvim_tree()
end

return M
