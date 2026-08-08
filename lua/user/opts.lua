-- cfg.opts

local opt = vim.opt
local o = vim.o
local g = vim.g

-- Teclas lider
g.mapleader = " "
g.maplocalleader = " "

-- Mostrar número de línea (opcionalmente relativo)
o.number = true
o.relativenumber = true

-- Anchura mínima de la columna de números
o.numberwidth = 2

-- Resaltar la línea actual, pero solo el número
o.cursorline = true
o.cursorlineopt = "number"

-- Mantiene siempre visible la columna de signos (diagnósticos, git, etc.)
o.signcolumn = "yes"

-- No mostrar la posición en la barra inferior
o.ruler = false

-- No mostrar el modo (-- INSERT --, etc.), ya lo enseña la statusline
o.showmode = false

-- Usar una única statusline global para todas las ventanas
o.laststatus = 3

-- Oculta el mensaje de intro al arrancar Neovim
opt.shortmess:append "sI"

-- Lineas largas NO se wrapean
o.wrap = false
-- ... en caso de wrapear, añade indexación
o.breakindent = true

-- Dejar margen vertical para que el cursor no quede pegado arriba o abajo
o.scrolloff = 1

-- Mantener estable la vista al abrir o cerrar splits
o.splitkeep = "screen"

-- Decidir dónde se abren los nuevos splits
o.splitright = true
o.splitbelow = true

-- Mostrar ciertos caracteres invisibles
o.list = false
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Oculta los ~ del final del buffer vacío
opt.fillchars = { eob = " " }

-- Activar truecolor (24-bit), necesario para cualquier colorscheme moderno
o.termguicolors = true

-- Activa el ratón en todos los modos
o.mouse = "a"

-- Autoindentación inteligente
o.smartindent = true

-- Fuente única para expandtab/shiftwidth/tabstop/softtabstop. Conform consume
-- esta misma política para que escribir y formatear produzcan el mismo estilo.
require("sabunv.indent").setup(require "user.indent")

-- Búsqueda sin distinguir mayúsculas/minúsculas,
-- salvo que se use \C o haya mayúsculas en el patrón
o.ignorecase = true
o.smartcase = true

-- Permite que h/l y las flechas pasen a la línea anterior/siguiente al llegar al borde
opt.whichwrap:append "<>[]hl"

-- Previsualizar sustituciones mientras se escriben
o.inccommand = "split"

-- Tiempo para decidir si una secuencia de teclas ha terminado
o.timeoutlen = 300

-- Reduce el tiempo de espera para eventos como swapfile o plugins reactivos
o.updatetime = 250

-- Guardar el historial de deshacer entre sesiones
o.undofile = true

-- Si una operación falla por cambios sin guardar (por ejemplo :q),
-- mostrar un diálogo preguntando si se quieren guardar
o.confirm = true

-- Configuración de diagnósticos LSP
local x = vim.diagnostic.severity
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = "single" },
  underline = false,

  -- Mostrar el texto del diagnóstico al final de la línea
  virtual_text = { prefix = "󰈅" },
  -- virtual_text = { prefix = "" },
  signs = {
    text = {
      [x.ERROR] = "󰅙",
      [x.WARN] = "",
      [x.INFO] = "󰋼",
      [x.HINT] = "󰌵",
    },
  },

  -- No mostrar diagnósticos en líneas virtuales debajo
  virtual_lines = false,

  -- Abrir automáticamente el float al saltar entre diagnósticos con [d y ]d
  jump = { float = true },
}

-- Desactiva providers externos que vienen por defecto porque no se usan
-- g.loaded_node_provider = 0
-- g.loaded_python3_provider = 0
-- g.loaded_perl_provider = 0
-- g.loaded_ruby_provider = 0

vim.filetype.add {
  filename = {
    README = "markdown",
    LICENSE = "markdown",
  },
}
vim.filetype.add {
  extension = {
    mdx = "markdown.mdx",
  },
}
-- Plantillas Go: nvim solo reconoce `.tmpl` como `template` genérico y nada
-- para `.gotmpl`/`.gohtml`. Los tres se mapean a `gotmpl` porque es el único
-- filetype que gopls atiende como plantilla (LSP + tipos). El contenido de
-- `.gohtml` también es html/template, así que no se pierde nada.
vim.filetype.add {
  extension = {
    tmpl = "gotmpl", -- html/template (gopls)
    gotmpl = "gotmpl", -- text/template (gopls)
    gohtml = "gotmpl", -- html/template (gopls)
  },
}
vim.filetype.add({
  extension = {
    qml = "qml",
    qmljs = "qmljs",
  },
})
