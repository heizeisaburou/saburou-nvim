---@meta

---@diagnostic disable: duplicate-doc-alias, duplicate-doc-field

---@class sabunv.nvim.opts
---@field library? string[]
---@field globals? string[]

---@class sabunv.nvim.luarc
---@field diagnostics { globals: string[] }
---@field workspace { library: string[] }

-------------------------------------------------------------------------------
-- OLD PENDIENTE DE REVISION
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--- Primitive enums
--------------------------------------------------------------------------------

---@alias HzsrBufferlineSeparatorStyle
---| "thin"
---| "slant"
---| "slope"

---@alias HzsrBufferlineSeparatorColor
---| "gray"
---| "blue"

---@alias HzsrTransparentMode
---| "none"
---| "tree"
---| "bg"
---| "both"

---@alias HzsrIntegrationName
---| "bufferline"
---| "statuscol"
---| "nvimtree"
---| "lualine"

-------------------------------------------------------------------------------
--- Theme opts
--------------------------------------------------------------------------------

---@class HzsrThemeOpts
---@field bufferline? HzsrBufferlineOpts
---@field statuscol? HzsrStatuscolOpts
---@field nvimtree? HzsrNvimtreeOpts
---@field lualine? HzsrLualineOpts
---@field transparent? HzsrTransparentMode

---@class HzsrThemeInternalOpts
---@field bufferline HzsrBufferlineInternalOpts
---@field statuscol HzsrStatuscolInternalOpts
---@field nvimtree HzsrNvimtreeInternalOpts
---@field lualine HzsrLualineInternalOpts
---@field transparent HzsrTransparentMode

-------------------------------------------------------------------------------
--- Integration
--------------------------------------------------------------------------------

---@class HzsrIntegration
---@field integrate fun(opts: HzsrThemeInternalOpts)

---@class HzsrIntegrationSpec
---@field plugin string
---@field module HzsrIntegration

-------------------------------------------------------------------------------
--- Bufferline
--------------------------------------------------------------------------------

---@class HzsrBufferlineOpts
---@field enabled? boolean
---@field sep_style? HzsrBufferlineSeparatorStyle
---@field sep_color? HzsrBufferlineSeparatorColor

---@class HzsrBufferlineInternalOpts
---@field enabled boolean
---@field sep_style HzsrBufferlineSeparatorStyle
---@field sep_color HzsrBufferlineSeparatorColor

-------------------------------------------------------------------------------
--- Lualine
--------------------------------------------------------------------------------

---@class HzsrLualineOpts
---@field enabled? boolean

---@class HzsrLualineInternalOpts
---@field enabled boolean

-------------------------------------------------------------------------------
--- Nvimtree
--------------------------------------------------------------------------------

---@class HzsrNvimtreeOpts
---@field enabled? boolean

---@class HzsrNvimtreeInternalOpts
---@field enabled boolean

-------------------------------------------------------------------------------
--- Statuscol
--------------------------------------------------------------------------------

---@class HzsrStatuscolOpts
---@field enabled? boolean

---@class HzsrStatuscolInternalOpts
---@field enabled boolean

-------------------------------------------------------------------------------
--- Infra / registry
--------------------------------------------------------------------------------

---@class HzsrGeneratedDefaultOpts
---@field bufferline HzsrBufferlineEnabledOnlyOpts
---@field statuscol HzsrEnabledOnlyOpts
---@field nvimtree HzsrEnabledOnlyOpts
---@field lualine HzsrEnabledOnlyOpts

---@class HzsrEnabledOnlyOpts
---@field enabled boolean

---@class HzsrBufferlineEnabledOnlyOpts
---@field enabled boolean
