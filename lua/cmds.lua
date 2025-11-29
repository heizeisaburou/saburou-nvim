local M = {}

M.setup = function()
    -- Buffer commands
    vim.api.nvim_create_user_command("Bd", function()
        require("nvchad.tabufline").close_buffer()
    end, {})

    vim.api.nvim_create_user_command("Bda", function()
        require("nvchad.tabufline").closeAllBufs(false)
    end, {})

    vim.api.nvim_create_user_command("Bdat", function()
        -- Includes this buffer (at == all, this)
        require("nvchad.tabufline").closeAllBufs(true)
    end, {})

    vim.api.nvim_create_user_command("Bdr", function()
        -- Includes this buffer (at == all, this)
        require("nvchad.tabufline").closeBufs_at_direction "right"
    end, {})

    vim.api.nvim_create_user_command("Bdl", function()
        -- Includes this buffer (at == all, this)
        require("nvchad.tabufline").closeBufs_at_direction "left"
    end, {})

    vim.api.nvim_create_user_command("Bp", function()
        local prev_buf = vim.fn.bufnr "#"
        if prev_buf == -1 or (not vim.api.nvim_buf_is_loaded(prev_buf)) then
            vim.notify("No previous buffer", vim.log.levels.INFO)
            return
        end
        require("nvchad.tabufline").goto_buf(prev_buf)
    end, {})
end

return M
