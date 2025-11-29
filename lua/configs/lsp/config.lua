-- local lspconfig = require "nvchad.configs.lspconfig"
local Servers = require "configs.lsp.servers"
local Methods = require "methods"
local overloads = require "configs.lsp.overloads"
local lsp_file_operations = require "lsp-file-operations"

local M = {}

local E = vim.log.levels.ERROR
local api = vim.api
local lsp = vim.lsp
local ms = require("vim.lsp.protocol").Methods
local util = require "vim.lsp.util"
local hover_ns = api.nvim_create_namespace "nvim.lsp.hover_range"

--- @param params? table
--- @return fun(client: vim.lsp.Client): lsp.TextDocumentPositionParams
local function client_positional_params(params)
    local win = api.nvim_get_current_win()
    return function(client)
        local ret = util.make_position_params(win, client.offset_encoding)
        if params then
            ret = vim.tbl_extend("force", ret, params)
        end
        return ret
    end
end
--- @param config? vim.lsp.buf.hover.Opts
function M.hover(config)
    config = config or {}
    config.focus_id = ms.textDocument_hover

    -- local funcion_resultante = client_positional_params()
    -- vim.notify("La ejecución llega aquí?" .. vim.inspect(funcion_resultante), E)
    --
    lsp.buf_request_all(0, ms.textDocument_hover, client_positional_params(), function(results, ctx)
        local bufnr = assert(ctx.bufnr)

        if api.nvim_get_current_buf() ~= bufnr then
            -- Ignore result since buffer changed. This happens for slow language servers.
            return
        end

        -- Filter errors from results
        local results1 = {} --- @type table<integer,lsp.Hover>

        for client_id, resp in pairs(results) do
            local err, result = resp.err, resp.result
            if err then
                lsp.log.error(err.code, err.message)
            elseif result then
                results1[client_id] = result
            end
        end

        if vim.tbl_isempty(results1) then
            if config.silent ~= true then
                vim.notify("No information available", vim.log.levels.INFO)
            end
            return
        end

        local contents = {} --- @type string[]

        local nresults = #vim.tbl_keys(results1)

        local format = "markdown"

        for client_id, result in pairs(results1) do
            local client = assert(lsp.get_client_by_id(client_id))
            if nresults > 1 then
                -- Show client name if there are multiple clients
                contents[#contents + 1] = string.format("# %s", client.name)
            end
            if type(result.contents) == "table" and result.contents.kind == "plaintext" then
                if #results1 == 1 then
                    format = "plaintext"
                    contents = vim.split(result.contents.value or "", "\n", { trimempty = true })
                else
                    -- Surround plaintext with ``` to get correct formatting
                    contents[#contents + 1] = "```"
                    vim.list_extend(
                        contents,
                        vim.split(result.contents.value or "", "\n", { trimempty = true })
                    )
                    contents[#contents + 1] = "```"
                end
            else
                vim.list_extend(contents, util.convert_input_to_markdown_lines(result.contents))
            end
            local range = result.range
            if range then
                local start = range.start
                local end_ = range["end"]
                local start_idx = util._get_line_byte_from_position(bufnr, start, client.offset_encoding)
                local end_idx = util._get_line_byte_from_position(bufnr, end_, client.offset_encoding)

                vim.hl.range(
                    bufnr,
                    hover_ns,
                    "LspReferenceTarget",
                    { start.line, start_idx },
                    { end_.line, end_idx },
                    { priority = vim.hl.priorities.user }
                )
            end
            contents[#contents + 1] = "---"
        end

        -- Remove last linebreak ('---')
        contents[#contents] = nil

        if vim.tbl_isempty(contents) then
            if config.silent ~= true then
                vim.notify "No information available"
            end
            return
        end

        local _, winid = lsp.util.open_floating_preview(contents, format, config)

        api.nvim_create_autocmd("WinClosed", {
            pattern = tostring(winid),
            once = true,
            callback = function()
                api.nvim_buf_clear_namespace(bufnr, hover_ns, 0, -1)
                return true
            end,
        })
    end)
end

M.configs = Servers.configs
M.to_install = Servers.to_install

local map = vim.keymap.set
---@diagnostic disable-next-line: unused-local
local unmap = vim.keymap.set

---@diagnostic disable-next-line: unused-local
function M.mappings(client, bufnr)
    local function genopts(desc)
        return { buffer = bufnr, desc = "LSP " .. desc }
    end

    -- TODO: Categorizar funciones de alguna manera, para que podamos definirlas fuera de config.lua
    -- en mappings.lua o en la sección mappings de cada plugin.

    map("n", "gd", vim.lsp.buf.declaration, genopts "Go to declaration")
    map("n", "gd", vim.lsp.buf.definition, genopts "Go to definition")
    map("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, genopts "Add workspace folder")
    map("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, genopts "Remove workspace folder")

    map("n", "<leader>lwl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, genopts "list workspace folders")

    map("n", "<leader>lR", require "nvchad.lsp.renamer", genopts "NVRenamer")
    map("n", "<leader>lt", vim.lsp.buf.type_definition, genopts "Go to type definition")

    -- Open line diagnostics
    map("n", "<leader>ld", function()
        vim.notify("  Showing line diagnostics ...", vim.log.levels.INFO)
        local _, float_win = vim.diagnostic.open_float {
            scope = "line",
        }
        if float_win then
            vim.api.nvim_set_current_win(float_win)
        end
    end, genopts "Open line diagnostics")

    -- Toggle update_in_insert
    map("n", "<leader>lu", function()
        local cfg = vim.diagnostic.config() or {}
        local new = not cfg.update_in_insert
        vim.diagnostic.config { update_in_insert = new }
        vim.notify("update_in_insert = " .. tostring(new), vim.log.levels.INFO)
    end, genopts "update_in_insert")

    -- Virtual lines toggle (requires lsp_lines.nvim)
    map("n", "<leader>lv", function()
        local virtual_lines_enabled = vim.diagnostic.config().virtual_lines or false
        virtual_lines_enabled = not virtual_lines_enabled

        vim.diagnostic.config {
            virtual_lines = virtual_lines_enabled,
            virtual_text = not virtual_lines_enabled,
        }
        vim.notify("virtual_lines = " .. tostring(virtual_lines_enabled), vim.log.levels.INFO)
    end, genopts "virtual_lines")

    map("n", "K", function()
        -- Debug: avisar que se ejecutó el mapeo
        M.hover { silent = false }
    end, { buffer = bufnr, desc = "LSP Hover / Debug" })
end

M.on_attach = function(client, bufnr)
    M.mappings(client, bufnr)

    -- Cargar configuración lsp-overloads
    overloads.setup(client, bufnr)
end

---@diagnostic disable-next-line: unused-local
M.on_init = function(client, bufnr)
    if vim.fn.has "nvim-0.11" ~= 1 then
        if client.supports_method "textDocument/semanticTokens" then
            client.server_capabilities.semanticTokensProvider = nil
        end
    else
        if client:supports_method "textDocument/semanticTokens" then
            client.server_capabilities.semanticTokensProvider = nil
        end
    end
end

M.capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities = vim.tbl_deep_extend("force", M.capabilities, lsp_file_operations.default_capabilities())
M.capabilities.textDocument.completion.completionItem = {
    documentationFormat = { "markdown", "plaintext" },
    snippetSupport = true,
    preselectSupport = true,
    insertReplaceSupport = true,
    labelDetailsSupport = true,
    deprecatedSupport = true,
    commitCharactersSupport = true,
    tagSupport = { valueSet = { 1 } },
    resolveSupport = {
        properties = {
            "documentation",
            "detail",
            "additionalTextEdits",
        },
    },
}

function M.setup()
    dofile(vim.g.base46_cache .. "lsp")
    require("nvchad.lsp").diagnostic_config()

    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            M.on_attach(client, args.buf)
        end,
    })

    vim.lsp.config("*", { capabilities = M.capabilities, on_init = M.on_init })

    for server, cfg_cb in pairs(M.configs) do
        if vim.tbl_contains(M.to_install, server) then
            local cfg = cfg_cb()
            if cfg then
                vim.lsp.config(server, cfg)
            end
        end
    end

    vim.lsp.enable(M.to_install)
end

return M
