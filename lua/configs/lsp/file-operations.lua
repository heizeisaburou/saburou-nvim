local M = {}

M.config = function()
    require("lsp-file-operations").setup {
        -- Mostrar logs de debug (por defecto: false)
        debug = false,

        -- Selecciona qué operaciones de archivos activar
        operations = {
            willRenameFiles = true,
            didRenameFiles = true,
            willCreateFiles = true,
            didCreateFiles = true,
            willDeleteFiles = true,
            didDeleteFiles = true,
        },

        -- Timeout en milisegundos para renombres
        timeout_ms = 10000,
    }
end

return M
