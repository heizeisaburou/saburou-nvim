-- lzy.l_treesitter

local M = {}

M.languages = {
  "lua",
  "luadoc",
  "markdown_inline",
  "markdown",
  --
  --
  --
  "bash",
  "c_sharp",
  "c",
  "clojure",
  "cmake",
  "cpp",
  "css",
  "dart", -- externo
  "elixir",
  "fish",
  "fsharp",
  "go",
  "gomod",
  "gosum",
  "gotmpl",
  "gowork",
  "haskell",
  "heex",
  "html",
  "htmldjango",
  "java",
  "javascript",
  "jinja", -- requiere jinja_inline (dependencia del parser)
  "json",
  "json5",
  "kotlin",
  "liquid",
  "make",
  "ocaml_interface",
  "ocaml",
  "php",
  "printf",
  "pug",
  "python",
  "qmljs",
  "ruby",
  "rust",
  "scala",
  "svelte",
  "swift",
  "toml",
  "tsx", -- typescriptreact
  "twig",
  "typescript",
  "typst",
  "vim",
  "vimdoc",
  "vue",
  "yaml",
  "zig",
}

M.enabled_highlights = {
  bash = true,
  c = true,
  clojure = true,
  cmake = true,
  cpp = true,
  cs = true,
  css = true,
  dart = true,
  edn = true,
  elixir = true,
  fish = true,
  fsharp = true,
  go = true,
  gomod = true,
  gosum = true,
  gotmpl = true,
  gowork = true,
  haskell = true,
  html = true,
  htmldjango = true,
  java = true,
  javascript = true,
  jinja = true,
  json = true,
  json5 = true,
  kotlin = true,
  lhaskell = true, -- `.lhs`; requiere también el alias de M.language_aliases
  liquid = true,
  lua = true,
  luadoc = true,
  make = true,
  markdown = true,
  markdown_inline = true,
  ocaml = true,
  ocamlinterface = true,
  php = true,
  printf = true,
  pug = true,
  python = true,
  qml = true,
  ruby = true,
  rust = true,
  scala = true,
  svelte = true,
  swift = true,
  toml = true,
  twig = true,
  typescript = true,
  typescriptreact = true,
  typst = true,
  vim = true,
  vimdoc = true,
  vue = true,
  yaml = true,
  zig = true,
}

-- Algunos filetypes no comparten nombre con su parser. nvim-treesitter ya
-- registra `cs -> c_sharp` y `ocamlinterface -> ocaml_interface`; estos alias
-- adicionales pertenecen a los filetypes secundarios que añadimos.
-- Filetypes que no comparten nombre con su parser. nvim-treesitter ya registra
-- los casos conocidos (cs -> c_sharp, ocamlinterface -> ocaml_interface). Sin
-- entradas por ahora; las plantillas Go usan directamente `gotmpl`.
M.language_aliases = {}

local function install_all()
  require("nvim-treesitter").install(M.languages)
end

local function start_for_buffer(bufnr)
  local ft = vim.bo[bufnr].filetype
  -- Los filetypes compuestos (p.ej. `yaml.ansible`) caen al base (`yaml`);
  -- `vim.treesitter.start` también resuelve el parser por el base.
  local base = vim.split(ft, ".", { plain = true })[1]

  if not (M.enabled_highlights[ft] or M.enabled_highlights[base]) then
    return
  end

  pcall(vim.treesitter.start, bufnr)
end

function M.setup()
  for filetype, language in pairs(M.language_aliases) do
    vim.treesitter.language.register(language, filetype)
  end

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
