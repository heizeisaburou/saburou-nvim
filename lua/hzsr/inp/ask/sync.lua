-- hzsr.inp.ask.sync

local M = {}

local function simple_vim_input(prompt, default, completion)
  if not completion or completion == "" then
    return vim.fn.input(prompt, default)
  end

  return vim.fn.input(prompt, default, completion)
end

--- Solicita al usuario un texto.
--- `completion` se pasa directamente a `vim.fn.input()`.
--- Para completado personalizado, usa:
--- - `"custom,FuncName"`
--- - `"customlist,FuncName"`
---@param prompt? string Texto que se muestra al usuario.
---@param default? string Valor inicial del campo de entrada.
---@param completion? hzsr.inp.ask.completion|string Tipo de completado para `vim.fn.input()`.
---@return string|nil input string si se respondió, nil si se abortó
function M.ask(prompt, default, completion)
  prompt = prompt or ""
  default = default or ""

  ok, res = pcall(simple_vim_input, prompt, default, completion)

  if not ok then
    if hzsr.nvim.error.is_keyboard_interrupt(res) then
      return nil
    end
    error(res)
  end

  return res
end

return M
