-- lua/configs/aerial.lua

local noremap_silent = { noremap = true, silent = true }
local map = vim.keymap.set

-- Aerial
map("n", "{", "<cmd>AerialPrev<CR>", noremap_silent)
map("n", "}", "<cmd>AerialNext<CR>", noremap_silent)
map("n", "<leader>q", "<cmd>AerialToggle<CR>")

--> ctrl+q también está disponible pero mejor alt+q para sacar agilidad
-- map("n", "<C-q>", "<cmd>AerialToggle<CR>")
map("n", "<A-q>", "<cmd>AerialToggle<CR>")

-- Devuelve la tabla de configuración para aerial.nvim
local opts = {
    view = { relativenumer = true },
    -- Prioridad de los backends para obtener los símbolos
    backends = { "treesitter", "lsp", "markdown", "man" },

    -- No abrir automáticamente al entrar en un buffer
    open_automatic = false,

    -- Cerrar la ventana de aerial si cambias de buffer
    close_automatic_events = { "switch_buffer" },

    -- No cerrar la ventana de aerial al seleccionar un símbolo
    close_on_select = false,

    -- Filtrar para mostrar solo los símbolos más relevantes
    filter_kind = {
        "Class",
        "Constructor",
        "Enum",
        "Function",
        "Interface",
        "Module",
        "Method",
        "Struct",
        "Property", -- Salen los get pero también las variables this, etc.
        -- "Field",
    },

    -- Mostrar guías en el árbol de símbolos
    show_guides = true,

    layout = {
        -- Ancho máximo de 40 columnas o 20% de la ventana
        max_width = { 50, 0.2 },
        -- Dirección por defecto para abrir la ventana
        default_direction = "prefer_right",
        -- Redimensionar para ajustar el contenido
        resize_to_content = true,
    },

    -- Comando a ejecutar después de saltar a un símbolo (para centrar la vista)
    post_jump_cmd = "normal! zz",

    -- Función para filtrar símbolos no deseados
    post_parse_symbol = function(bufnr, item, ctx)
        -- FILTRO 1: Asegurarse de que el símbolo tiene un nombre
        if not item.name or item.name == "" then
            return false
        end

        -- FILTRO 2: Ocultar si el nombre termina con "callback"
        -- La función string.match busca un patrón en la cadena.
        -- El patrón "%s*callback$" busca la palabra "callback" al final del nombre,
        -- permitiendo cualquier cantidad de espacios antes de ella.
        if string.match(item.name, "%s*callback$") then
            return false -- Oculta el símbolo si coincide
        end

        -- FILTRO 3: Ocultar nombres que empiezan por [ o {
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

require("aerial").setup(opts)
