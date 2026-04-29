-- lzy.l_cmp

local M = {}

local cmp = require "cmp"
local luasnip = require "luasnip"

local leave_key = "<C-x>"

-- ============================================================================
-- Helpers
-- ============================================================================

local function feedkeys(keys, mode)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true), mode or "n", true)
end

local function make_markdown_callout_source()
  local source = {}

  local items = {
    { label = "[!FAQ]", icon = "", name = "Faq" },
    { label = "[!BUG]", icon = "", name = "Bug" },
    { label = "[!TIP]", icon = "", name = "Tip" },
    { label = "[!DONE]", icon = "", name = "Done" },
    { label = "[!TODO]", icon = "󰄱", name = "Todo" },
    { label = "[!TLDR]", icon = "󰒢", name = "Tldr" },
    { label = "[!FAIL]", icon = "", name = "Fail" },
    { label = "[!CITE]", icon = "󰌆", name = "Cite" },
    { label = "[!INFO]", icon = "", name = "Info" },
    { label = "[!NOTE]", icon = "", name = "Note" },
    { label = "[!HINT]", icon = "", name = "Hint" },
    { label = "[!HELP]", icon = "", name = "Help" },
    { label = "[!QUOTE]", icon = "", name = "Quote" },
    { label = "[!CHECK]", icon = "", name = "Check" },
    { label = "[!ERROR]", icon = "", name = "Error" },
    { label = "[!DANGER]", icon = "", name = "Danger" },
    { label = "[!WARNING]", icon = "", name = "Warning" },
    { label = "[!SUCCESS]", icon = "", name = "Success" },
    { label = "[!FAILURE]", icon = "", name = "Failure" },
    { label = "[!SUMMARY]", icon = "󰨸", name = "Summary" },

    -- aliases comunes
    { label = "[!ABSTRACT]", icon = "󰨸", name = "Abstract" },
    { label = "[!QUESTION]", icon = "", name = "Question" },
    { label = "[!EXAMPLE]", icon = "󰉹", name = "Example" },
    { label = "[!IMPORTANT]", icon = "", name = "Important" },
    { label = "[!CAUTION]", icon = "", name = "Caution" },
    { label = "[!ATTENTION]", icon = "", name = "Attention" },
    { label = "[!MISSING]", icon = "", name = "Missing" },
  }

  function source:is_available()
    local ft = vim.bo.filetype
    return ft == "markdown" or ft == "markdown.mdx" or ft == "quarto"
  end

  function source:get_trigger_characters()
    return { ">", "!" }
  end

  function source:complete(params, callback)
    local line = params.context.cursor_before_line

    -- Solo después de `>`:
    --   >
    --   > !
    --   > !ti
    local start_after_gt = line:match "^%s*>()%s*!?[%w_%-]*$"

    if not start_after_gt then
      callback { items = {}, isIncomplete = false }
      return
    end

    local completion_items = vim.tbl_map(function(item)
      local title = item.label:gsub("%[%!", ""):gsub("%]", "")

      return {
        label = item.label,
        kind = cmp.lsp.CompletionItemKind.Value,
        insertTextFormat = cmp.lsp.InsertTextFormat.Snippet,

        insertText = " " .. item.label .. " ${1:" .. title .. "}\n>\n> ${2:...}$0",
        data = {
          icon = item.icon,
          name = item.name,
        },
      }
    end, items)

    callback {
      items = completion_items,
      isIncomplete = false,
    }
  end

  return source
end

-- ============================================================================
-- Tab behavior profiles
-- ============================================================================

local function leave_snippet()
  pcall(luasnip.unlink_current)

  vim.schedule(function()
    local mode = vim.api.nvim_get_mode().mode

    if mode ~= "n" then
      feedkeys("<Esc>", "n")
    end
  end)
end

local function count_snippet_jumps(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local node = luasnip.session.current_nodes[bufnr]

  if not node then
    return 0
  end

  local key = direction > 0 and "next" or "prev"
  local count = 0
  local seen = {}

  while node and node[key] and not seen[node[key]] do
    node = node[key]
    seen[node] = true
    count = count + 1

    -- Guardia por si algún snippet raro crea ciclo.
    if count > 64 then
      break
    end
  end

  -- LuaSnip mantiene un nodo extra/fantasma en los bordes del snippet.
  -- Lo descontamos para que Tab/S-Tab salgan al llegar al borde real.
  return math.max(count - 1, 0)
end

local function tab_snippet_only()
  return {
    ["<Tab>"] = cmp.mapping(function(fallback)
      if luasnip.in_snippet() then
        if count_snippet_jumps(1) <= 1 then
          leave_snippet()
        elseif luasnip.jumpable(1) then
          luasnip.jump(1)
        else
          leave_snippet()
        end
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if luasnip.in_snippet() then
        if count_snippet_jumps(-1) <= 1 then
          leave_snippet()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          leave_snippet()
        end
      else
        fallback()
      end
    end, { "i", "s" }),
  }
end

local function tab_cmp_and_snippet()
  return {
    ["<Tab>"] = cmp.mapping(function(fallback)
      if luasnip.in_snippet() then
        if count_snippet_jumps(1) <= 1 then
          leave_snippet()
        elseif luasnip.jumpable(1) then
          luasnip.jump(1)
        else
          leave_snippet()
        end
      elseif cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if luasnip.in_snippet() then
        if count_snippet_jumps(-1) <= 1 then
          leave_snippet()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          leave_snippet()
        end
      elseif cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }
end

-- Cambia aquí el perfil de Tab.
--
-- Recomendado si quieres que cmp no moleste:
local tab_mapping = tab_snippet_only()

-- Alternativa si quieres seleccionar opciones con Tab:
-- local tab_mapping = tab_cmp_and_snippet()

-- ============================================================================
-- Options
-- ============================================================================

M.opts = {
  -- No preseleccionamos automáticamente.
  preselect = cmp.PreselectMode.None,

  completion = {
    completeopt = "menu,menuone,noselect",
  },

  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },

  mapping = vim.tbl_extend("force", {
    -- Cerrar cmp con Ctrl-q.
    --
    -- Si el menú de cmp está abierto:
    --   - lo cierra.
    --
    -- Si el menú no está abierto:
    --   - mantiene el comportamiento normal de Ctrl-q.
    [leave_key] = function()
      if cmp.visible() then
        cmp.close()
      else
        feedkeys(leave_key)
      end
    end,

    -- Navegación explícita del menú de cmp.
    --
    -- Estas teclas quedan como forma principal de moverse por sugerencias
    -- cuando se usa el perfil tab_snippet_only().
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-n>"] = cmp.mapping.select_next_item(),

    -- Abrir completado manualmente.
    ["<C-Space>"] = cmp.mapping.complete(),
    -- -------------------------------------------------------------------------

    ["<BS>"] = cmp.mapping(function(fallback)
      if vim.fn.mode() == "s" then
        feedkeys "<C-g>c"
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<Del>"] = cmp.mapping(function(fallback)
      if vim.fn.mode() == "s" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-g>c", true, true, true), "n", true)
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<C-w>"] = cmp.mapping(function(fallback)
      if vim.fn.mode() == "s" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-g>c", true, true, true), "n", true)
      else
        fallback()
      end
    end, { "i", "s" }),

    -- -------------------------------------------------------------------------
    -- Mantener comportamiento normal de Ctrl-d.
    --
    -- No lo usamos para scroll de documentación porque Ctrl-d ya tiene
    -- un comportamiento útil en insert/terminal según el contexto.
    ["<C-d>"] = function()
      feedkeys "<C-d>"
    end,

    -- Ctrl-e va al final de línea en vez de cerrar cmp.
    --
    -- Para cerrar cmp usamos Ctrl-q.
    ["<C-e>"] = function()
      feedkeys "<End>"
    end,

    -- Scroll de documentación de cmp.
    --
    -- Se usa Ctrl-f / Ctrl-g para no pisar Ctrl-d.
    ["<C-f>"] = cmp.mapping.scroll_docs(-4),
    ["<C-g>"] = cmp.mapping.scroll_docs(4),

    -- Enter confirma solo si hay selección explícita.
    --
    -- select = false evita aceptar accidentalmente la primera sugerencia.
    ["<CR>"] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Insert,
      select = false,
    },
  }, tab_mapping),

  sources = {
    { name = "markdown_callouts" },
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "buffer" },
    { name = "nvim_lua" },
    { name = "async_path" },
  },

  -- Para debugging
  -- formatting = {
  --   format = function(entry, vim_item)
  --     vim_item.menu = ({
  --       nvim_lsp = "[LSP]",
  --       luasnip = "[Snip]",
  --       buffer = "[Buf]",
  --       nvim_lua = "[Lua]",
  --       async_path = "[Path]",
  --     })[entry.source.name] or ("[" .. entry.source.name .. "]")
  --
  --     return vim_item
  --   end,
  -- },
  formatting = {
    fields = { "abbr", "kind", "menu" },

    format = function(entry, vim_item)
      if entry.source.name == "markdown_callouts" then
        local data = entry.completion_item.data or {}

        vim_item.kind = "Value"
        vim_item.menu = ("  " .. (data.icon or "") .. " " .. (data.name or "")):gsub("%s+$", "")

        return vim_item
      end

      vim_item.menu = ({
        nvim_lsp = "[LSP]",
        luasnip = "[Snip]",
        buffer = "[Buf]",
        nvim_lua = "[Lua]",
        async_path = "[Path]",
      })[entry.source.name] or ("[" .. entry.source.name .. "]")

      return vim_item
    end,
  },
}

function M.setup()
  cmp.register_source("markdown_callouts", make_markdown_callout_source())
  cmp.setup(M.opts)
end

return M
