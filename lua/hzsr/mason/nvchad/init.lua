-- hzsr.mason.nvchad

-- SPDX-License-Identifier: GPL-3.0-only
-- SPDX-FileCopyrightText: NvChad contributors
-- SPDX-FileCopyrightText: 2026 Saburou
--
-- Derived from NvChad Mason tooling.
-- Source: https://github.com/NvChad/ui/blob/v3.0/lua/nvchad/mason/init.lua
-- Source branch: v3.0
-- Last relevant upstream commit for this file: 70f476840fbfbe983d3307f4cc4fbfea55e5faa9
--
-- This file is part of the NvChad-derived adapter in this `nvchad` directory.
--
-- See the accompanying LICENSE and NOTICE.md files in this directory.
--
-- Within this `nvchad` directory only, attribution to Saburou is not required
-- for reuse of my modifications.
--
-- Please preserve the NvChad copyright, license, and source notice.

local M = {}

local masonames = require "hzsr.mason.nvchad.names"
local pkgs = {}
local skipped = {}

M.get_pkgs = function()
  local tools = {}

  -- lsp
  local native_lsps = vim.tbl_keys(vim.lsp._enabled_configs or {})

  local lspconfig_lsps = require("lspconfig.util").available_servers()
  vim.list_extend(tools, lspconfig_lsps)
  vim.list_extend(tools, native_lsps)

  -- conform
  local conform_exists, conform = pcall(require, "conform")

  if conform_exists then
    for _, v in ipairs(conform.list_all_formatters()) do
      local fmts = vim.split(v.name:gsub(",", ""), "%s+")
      vim.list_extend(tools, fmts)
    end
  end

  -- nvim-lint
  local lint_exists, lint = pcall(require, "lint")

  if lint_exists then
    local linters = lint.linters_by_ft

    for _, v in pairs(linters) do
      vim.list_extend(tools, v)
    end
  end

  -- rm duplicates
  for _, v in pairs(tools) do
    if not vim.tbl_contains(pkgs, masonames[v]) and not vim.tbl_contains(skipped, masonames[v]) then
      table.insert(pkgs, masonames[v])
    end
  end

  return pkgs
end

local function parse_package(package_name)
  local name, version = package_name:match "^([^@]+)@?(.*)$"
  return {
    name = name,
    version = version ~= "" and version or nil,
  }
end

M.install_all = function()
  vim.cmd "Mason"

  local mr = require "mason-registry"
  return mr.refresh(function()
    for _, tool in ipairs(M.get_pkgs()) do
      local pkg = parse_package(tool)
      local p = mr.get_package(pkg.name)

      if not p:is_installed() then
        p:install { version = pkg.version }
      end
    end
  end)
end

return M
