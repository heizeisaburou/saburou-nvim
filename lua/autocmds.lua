require "nvchad.autocmds"

-- Temp Fix for Barbar Nvim
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
    callback = function(args)
        local bufnr = args.buf
        vim.bo[bufnr].expandtab = true -- insertar solo espacios
        vim.bo[bufnr].shiftwidth = 4 -- ancho de indentación
        vim.bo[bufnr].tabstop = 4 -- longitud visual de un tab
        -- vim.bo[bufnr].softtabstop = 0
        vim.bo[bufnr].smartindent = true -- indentación automática
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "aerial",
    callback = function()
        vim.wo.number = true
        vim.wo.relativenumber = true
    end,
})
