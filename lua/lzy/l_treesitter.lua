-- lzy.l_treesitter

local M = {}

M.languages = {
  "bash",
  "c",
  "cmake",
  "cpp",
  "css",
  "elixir",
  "heex",
  "fish",
  "go",
  "gomod",
  "gosum",
  "gotmpl",
  "gowork",
  "html",
  "htmldjango",
  "javascript",
  "json",
  "json5",
  "lua",
  "luadoc",
  "make",
  "markdown",
  "markdown_inline",
  "printf",
  "python",
  "rust",
  "toml",
  "vim",
  "vimdoc",
  "yaml",
}

M.enabled_highlights = {
  bash = true,
  c = true,
  cmake = true,
  cpp = true,
  css = true,
  elixir = true,
  fish = true,
  go = true,
  gomod = true,
  gosum = true,
  gotmpl = true,
  gowork = true,
  html = true,
  htmldjango = true,
  javascript = true,
  json = true,
  json5 = true,
  lua = true,
  luadoc = true,
  make = true,
  markdown = true,
  markdown_inline = true,
  printf = true,
  python = true,
  rust = true,
  toml = true,
  vim = true,
  vimdoc = true,
  yaml = true,
}

local function install_all()
  require("nvim-treesitter").install(M.languages)
end

local function start_for_buffer(bufnr)
  local ft = vim.bo[bufnr].filetype

  if not M.enabled_highlights[ft] then
    return
  end

  pcall(vim.treesitter.start, bufnr)
end

function M.setup()
  vim.api.nvim_create_user_command("TSInstallAll", function()
    install_all()
  end, {})

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("lzy_treesitter_start", { clear = true }),
    callback = function(args)
      start_for_buffer(args.buf)
    end,
  })

  -- Opcional: intenta instalar parsers al cargar el módulo.
  -- install_all()
end

return M
