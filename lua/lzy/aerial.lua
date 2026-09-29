-- lua/configs/aerial.lua

local M = {}

local function gen_maps()
  local map = vim.keymap.set
  map("n", "{", "<cmd>AerialPrev<CR>")
  map("n", "}", "<cmd>AerialNext<CR>")
  map("n", "<leader>q", "<cmd>AerialToggle<CR>")
  map("n", "<C-q>", "<cmd>AerialToggle<CR>")
end

--- Clases de símbolo que se muestran en el árbol.
---
--- `Constant` y `Variable` están para que se vean las constantes de módulo: las
--- `const` y los `var` de paquete de Go, los objetos de configuración de
--- TypeScript. Lo que declara una función entra también por aquí, porque
--- `filter_kind` sólo mira la clase y no sabe dónde vive el símbolo; eso se
--- descarta después, en `post_parse_symbol`.
local kinds = {
  "Class",
  "Constant",
  "Constructor",
  "Enum",
  "Function",
  "Interface",
  "Module",
  "Method",
  "Struct",
  "Property", -- Salen los get pero también las variables this, etc.
  "Variable",
  -- "Field",
}

--- Lenguajes cuyo servidor entrega los alias de tipo como una variable más.
local ts_filetypes = {
  typescript = true,
  typescriptreact = true,
}

--- Clases cuyo interior es cuerpo, no estructura: un `if` de una función y las
--- claves de un objeto literal están al mismo nivel de detalle, y ninguno de
--- los dos pinta nada en un índice del fichero.
local opaque_parents = {
  Constant = true,
  Constructor = true,
  Function = true,
  Method = true,
  Property = true, -- `vtsls` entrega los getters como Property, no como Method
  Variable = true,
}

--- Clases que sólo interesan si se declaran al nivel del módulo o de un tipo.
local nested_kinds = {
  Constant = true,
  Property = true,
  Variable = true,
}

--- Itera los ancestros de `item`, del más cercano al más lejano.
---@param item table
---@return fun(): table|nil
local function ancestors(item)
  local current = item
  return function()
    current = current.parent
    return current
  end
end

--- ¿Esta línea abre una declaración de alias de tipo?
---
--- Se mira el texto porque el servidor no distingue: el símbolo llega sin
--- `detail` y con la misma clase que una variable. El rango del símbolo empieza
--- en la línea de la declaración, modificadores incluidos.
---@param line string|nil
---@return boolean
local function declares_type(line)
  if not line then
    return false
  end
  local rest = line:gsub("^%s*", "")
  rest = rest:gsub("^export%s+", "")
  rest = rest:gsub("^declare%s+", "")
  return rest:match("^type%s") ~= nil
end

-- Devuelve la tabla de configuración para aerial.nvim
local opts = {
  view = { relativenumer = true },
  -- Prioridad de los backends para obtener los símbolos.
  -- LSP aporta la vista semántica y Tree-sitter funciona como respaldo local.
  backends = {
    ["_"] = { "lsp", "treesitter" },
    markdown = { "markdown", "treesitter" },
    man = { "man" },
  },

  -- No abrir automáticamente al entrar en un buffer
  open_automatic = false,

  -- Cerrar la ventana de aerial si cambias de buffer
  close_automatic_events = { "switch_buffer" },

  -- No cerrar la ventana de aerial al seleccionar un símbolo
  close_on_select = false,

  -- Filtrar para mostrar solo los símbolos más relevantes
  filter_kind = kinds,

  -- Mostrar guías en el árbol de símbolos
  show_guides = true,

  layout = {
    min_width = 60,
    -- Dirección por defecto para abrir la ventana
    default_direction = "prefer_right",
    -- Redimensionar para ajustar el contenido
    resize_to_content = true,
    -- Numeros relativos
    win_opts = {
      number = true,
      relativenumber = true,
    },
  },

  -- Comando a ejecutar después de saltar a un símbolo (para centrar la vista)
  post_jump_cmd = "normal! zz",

  -- Función para filtrar símbolos no deseados
  post_parse_symbol = function(bufnr, item, ctx)
    -- FILTRO 1: Asegurarse de que el símbolo tiene un nombre
    if not item.name or item.name == "" then
      return false
    end

    -- FILTRO 2: Ocultar lo que no se declara al nivel del módulo o de un
    -- tipo: las variables de trabajo de una función y las claves de los objetos
    -- literales. Interesan las constantes del módulo y los miembros de una
    -- clase. Se recorre la ascendencia entera y no sólo el padre, porque tanto
    -- las funciones como los objetos se anidan. Va antes de reetiquetar los
    -- alias de tipo: un `type` local todavía es una `Variable` aquí y así cae
    -- por el mismo sitio que el resto.
    if nested_kinds[item.kind] then
      for parent in ancestors(item) do
        if opaque_parents[parent.kind] then
          return false
        end
      end
    end

    -- FILTRO 3: En TypeScript los alias de tipo llegan como `Variable`, sin
    -- nada que los separe de un `const`. Se reconocen por el texto y se les
    -- cambia la clase a `Interface`, que es lo que ya hace el respaldo de
    -- Tree-sitter, para que compartan icono y resaltado con las interfaces.
    if
      ctx.backend_name == "lsp"
      and item.kind == "Variable"
      and ts_filetypes[vim.bo[bufnr].filetype]
      and declares_type(vim.api.nvim_buf_get_lines(bufnr, item.lnum - 1, item.lnum, false)[1])
    then
      item.kind = "Interface"
    end

    -- FILTRO 4: Ocultar si el nombre termina con "callback"
    -- La función string.match busca un patrón en la cadena.
    -- El patrón "%s*callback$" busca la palabra "callback" al final del nombre,
    -- permitiendo cualquier cantidad de espacios antes de ella.
    if string.match(item.name, "%s*callback$") then
      return false -- Oculta el símbolo si coincide
    end

    -- FILTRO 5: Ocultar nombres que empiezan por [ o {
    -- El patrón "^[\[{]" busca el carácter [ o { al principio de la cadena.
    -- El `[` necesita ser escapado con `\` dentro de `[]`.
    if string.match(item.name, "^[[{]") then
      return false
    end

    -- Si pasa todos los filtros, se muestra
    return true
  end,
  -- Aquí puedes agregar o modificar cualquier otra opción de la lista que pegaste.
}

function M.setup()
  require("aerial").setup(opts)
  gen_maps()
end

return M
