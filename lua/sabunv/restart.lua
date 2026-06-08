-- lua/sabunv/restart.lua
--
-- NOTE:
-- Este módulo lo generó ChatGPT en caliente para parchear la persistencia del
-- restart de Neovim. Seguramente requiere supervisión y ajustes finos.
--
-- En principio resuelve el problema principal: antes de reiniciar guarda estado
-- propio en restart.json, cierra nvim-tree antes de mksession para que no se
-- persista su hueco, y luego permite restaurar nvim-tree/bufferline de la forma
-- más simple posible sin sobrecomplicar la integración.
--
-- La restauración de bufferline depende de detalles internos del plugin
-- (`bufferline.state.components`), así que puede romperse si bufferline cambia
-- su implementación.

local M = {}

local DEFAULT_STATE = {
  restart = {
    pending = false,
  },
  nvim_tree = {
    pending = false,
    installed = false,
    open = false,
  },
  bufferline = {
    pending = false,
    installed = false,
    buffers = {},
  },
}

M.session = vim.fn.stdpath "state" .. "/restart_session.vim"

local function state_dir()
  return vim.fs.joinpath(hzsr.nvim.statedir(), "sabunv")
end

local function state_path()
  return vim.fs.joinpath(state_dir(), "restart.json")
end

local function ensure_state_dir()
  vim.fn.mkdir(state_dir(), "p")
end

local function read_file(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end

  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil
  end

  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)

  return data
end

local function write_file(path, data)
  ensure_state_dir()

  local fd, err = vim.uv.fs_open(path, "w", 438)
  if not fd then
    return false, err
  end

  vim.uv.fs_write(fd, data, 0)
  vim.uv.fs_close(fd)

  return true, nil
end

local function is_listed_normal_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if not vim.bo[bufnr].buflisted then
    return false
  end

  local buftype = vim.bo[bufnr].buftype
  if buftype ~= "" then
    return false
  end

  return true
end

local function uniq_push(list, seen, value)
  if type(value) ~= "string" or value == "" then
    return
  end

  if seen[value] then
    return
  end

  seen[value] = true
  table.insert(list, value)
end

local function normalize_state(state)
  state = type(state) == "table" and state or {}

  local normalized = vim.deepcopy(DEFAULT_STATE)

  if type(state.restart) == "table" then
    normalized.restart.pending = state.restart.pending == true
  end

  if type(state.nvim_tree) == "table" then
    normalized.nvim_tree.pending = state.nvim_tree.pending == true
    normalized.nvim_tree.installed = state.nvim_tree.installed == true
    normalized.nvim_tree.open = state.nvim_tree.open == true
  end

  if type(state.bufferline) == "table" then
    normalized.bufferline.pending = state.bufferline.pending == true
    normalized.bufferline.installed = state.bufferline.installed == true

    if type(state.bufferline.buffers) == "table" then
      local seen = {}

      for _, item in ipairs(state.bufferline.buffers) do
        if type(item) == "string" then
          uniq_push(normalized.bufferline.buffers, seen, item)
        elseif type(item) == "table" then
          uniq_push(normalized.bufferline.buffers, seen, item.name)
        end
      end
    end
  end

  return normalized
end

local function load_state()
  local raw = read_file(state_path())
  local decoded = nil

  if raw and raw ~= "" then
    local ok, result = pcall(vim.json.decode, raw)
    if ok and type(result) == "table" then
      decoded = result
    end
  end

  return normalize_state(decoded)
end

local function save_normalized_state(state)
  state = normalize_state(state)

  local json = vim.json.encode(state, { indent = "  " })
  local ok, err = write_file(state_path(), json .. "\n")

  if not ok then
    vim.notify("restart persistence: " .. tostring(err), vim.log.levels.ERROR)
  end

  return state
end

local function finish_pending(state)
  if not state.nvim_tree.pending and not state.bufferline.pending then
    state.restart.pending = false
  end

  return state
end

local function with_preserved_current(callback)
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()

  callback()

  vim.schedule(function()
    if vim.api.nvim_win_is_valid(current_win) then
      pcall(vim.api.nvim_set_current_win, current_win)

      if vim.api.nvim_buf_is_valid(current_buf) then
        pcall(vim.api.nvim_win_set_buf, current_win, current_buf)
      end
    elseif vim.api.nvim_buf_is_valid(current_buf) then
      pcall(vim.api.nvim_set_current_buf, current_buf)
    end
  end)
end

local function nvim_tree_state()
  local state = {
    pending = true,
    installed = false,
    open = false,
  }

  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return state
  end

  state.installed = true

  if api.tree and api.tree.is_visible then
    local visible_ok, visible = pcall(api.tree.is_visible)
    state.open = visible_ok and visible or false
  end

  return state
end

local function get_bufferline_order()
  local buffers = {}

  local ok_state, bufferline_internal_state = pcall(require, "bufferline.state")

  if
    ok_state
    and type(bufferline_internal_state) == "table"
    and type(bufferline_internal_state.components) == "table"
  then
    for index, component in ipairs(bufferline_internal_state.components) do
      local bufnr = component.id or component.bufnr or component.buffer

      if type(bufnr) == "number" and is_listed_normal_buffer(bufnr) then
        table.insert(buffers, {
          index = index,
          bufnr = bufnr,
          name = vim.api.nvim_buf_get_name(bufnr),
        })
      end
    end
  end

  if #buffers == 0 then
    for index, info in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
      local bufnr = info.bufnr

      if type(bufnr) == "number" and is_listed_normal_buffer(bufnr) then
        table.insert(buffers, {
          index = index,
          bufnr = bufnr,
          name = vim.api.nvim_buf_get_name(bufnr),
        })
      end
    end
  end

  return buffers
end

local function bufferline_state()
  local state = {
    pending = true,
    installed = false,
    buffers = {},
  }

  local ok_bufferline = pcall(require, "bufferline")
  if not ok_bufferline then
    return state
  end

  state.installed = true

  local seen = {}

  for _, item in ipairs(get_bufferline_order()) do
    uniq_push(state.buffers, seen, item.name)
  end

  return state
end

local function find_bufferline_index_by_name(name)
  for index, item in ipairs(get_bufferline_order()) do
    if item.name == name then
      return index, item.bufnr
    end
  end

  return nil, nil
end

local function set_current_buf_safely(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and not vim.wo[win].winfixbuf then
      pcall(vim.api.nvim_set_current_win, win)
      return pcall(vim.api.nvim_set_current_buf, bufnr)
    end
  end

  return false
end

local function restore_bufferline_order(saved_bufferline)
  if not saved_bufferline.installed then
    return
  end

  local ok_bufferline = pcall(require, "bufferline")
  if not ok_bufferline then
    return
  end

  if vim.fn.exists ":BufferLineMovePrev" ~= 2 then
    return
  end

  for target_index, name in ipairs(saved_bufferline.buffers) do
    local current_index, bufnr = find_bufferline_index_by_name(name)

    if current_index and bufnr then
      local ok = set_current_buf_safely(bufnr)

      if ok then
        while current_index > target_index do
          local moved = pcall(function()
            vim.cmd.BufferLineMovePrev()
          end)

          if not moved then
            break
          end

          current_index = current_index - 1
        end
      end
    end
  end
end

local function restore_nvim_tree_window(saved_nvim_tree)
  if not saved_nvim_tree.installed or not saved_nvim_tree.open then
    return
  end

  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return
  end

  if not api.tree or not api.tree.open then
    return
  end

  pcall(api.tree.open)
end

local function is_bufferline_ready()
  local ok_state, bufferline_internal_state = pcall(require, "bufferline.state")
  if not ok_state or type(bufferline_internal_state) ~= "table" then
    return false
  end

  return type(bufferline_internal_state.components) == "table" and #bufferline_internal_state.components > 0
end

local function save_all_fn()
  local save = hzsr and hzsr.edt and hzsr.edt.io and hzsr.edt.io.save

  if type(save) ~= "table" then
    return nil
  end

  if type(save.save_all) == "function" then
    return save.save_all
  end

  if type(save.save_all) == "table" and type(save.save_all.save_all) == "function" then
    return save.save_all.save_all
  end

  return nil
end

local function report_has_status(report, wanted)
  if type(report) ~= "table" then
    return false
  end

  if report.status == wanted then
    return true
  end

  for _, value in pairs(report) do
    if type(value) == "table" and report_has_status(value, wanted) then
      return true
    end
  end

  return false
end

local function report_has_bad_failure(report)
  if type(report) ~= "table" then
    return report == false
  end

  local status = tostring(report.status or ""):lower()

  if report.ok == false and not status:match "reject" and not status:match "cancel" then
    return true
  end

  if status:match "error" or status:match "fail" then
    return true
  end

  for _, value in pairs(report) do
    if type(value) == "table" and report_has_bad_failure(value) then
      return true
    end
  end

  return false
end

function M.path()
  return state_path()
end

function M.collect_state()
  return {
    restart = {
      pending = true,
    },
    nvim_tree = nvim_tree_state(),
    bufferline = bufferline_state(),
  }
end

function M.save_state(state)
  return save_normalized_state(state or M.collect_state())
end

function M.save_all()
  local fn = save_all_fn()

  if not fn then
    vim.notify("restart: hzsr.edt.io.save.save_all no está disponible", vim.log.levels.ERROR)
    return false, { force = false }
  end

  local ok, report = pcall(fn, {
    confirm = true,
    explicit_cancel = true,
    async = nil,
  })

  if not ok then
    vim.notify("restart: save_all falló: " .. tostring(report), vim.log.levels.ERROR)
    return false, { force = false }
  end

  local status = hzsr and hzsr.edt and hzsr.edt.io and hzsr.edt.io.status

  if type(status) == "table" then
    if report_has_status(report, status.CANCEL) then
      return false, { force = false, report = report }
    end

    if report_has_status(report, status.REJECT) then
      return true, { force = true, report = report }
    end
  end

  if report_has_bad_failure(report) then
    return false, { force = false, report = report }
  end

  return true, { force = false, report = report }
end

function M.restore_bufferline_when_ready(attempt)
  attempt = attempt or 1

  if attempt > 20 then
    return
  end

  if not is_bufferline_ready() then
    vim.schedule(function()
      M.restore_bufferline_when_ready(attempt + 1)
    end)
    return
  end

  M.restore_bufferline()
end

function M.restore_bufferline()
  local state = load_state()

  if not state.restart.pending or not state.bufferline.pending then
    return
  end

  with_preserved_current(function()
    restore_bufferline_order(state.bufferline)
  end)

  state.bufferline.pending = false
  save_normalized_state(finish_pending(state))
end

function M.restore_nvim_tree()
  local state = load_state()

  if not state.restart.pending or not state.nvim_tree.pending then
    return
  end

  with_preserved_current(function()
    restore_nvim_tree_window(state.nvim_tree)
  end)

  state.nvim_tree.pending = false
  save_normalized_state(finish_pending(state))
end

function M.restore_state()
  local state = load_state()

  if not state.restart.pending then
    return
  end

  with_preserved_current(function()
    if state.bufferline.pending then
      restore_bufferline_order(state.bufferline)
      state.bufferline.pending = false
    end

    if state.nvim_tree.pending then
      restore_nvim_tree_window(state.nvim_tree)
      state.nvim_tree.pending = false
    end
  end)

  state.restart.pending = false
  save_normalized_state(state)
end

function M.close_opencode()
  local ok, opencode = pcall(require, "lzy.l_opencode")
  if not ok or type(opencode.kill_opencode) ~= "function" then
    return
  end

  pcall(opencode.kill_opencode)
end

function M.close_nvim_tree()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      local name = vim.api.nvim_buf_get_name(buf)

      if ft == "NvimTree" or name:match "NvimTree_" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end
end

-- TODO: implementar persistencia/restauración de Aerial si algún día hace falta.
function M.close_aerial()
  local ok, aerial = pcall(require, "aerial")
  if not ok then
    return
  end

  if aerial.close then
    pcall(aerial.close)
    return
  end

  -- Fallback por si la API no está disponible o cambia.
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype

      if ft == "aerial" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end
end

function M.restart()
  coroutine.wrap(function()
    local session = M.session

    -- Capturar estado actual en memoria, pero no persistirlo todavía.
    local state = M.collect_state()

    -- Guardar buffers modificados con la política de hzsr.
    -- CANCEL aborta.
    -- REJECT significa "no guardar", pero seguimos con restart forzado.
    local saved, save_result = M.save_all()
    if not saved then
      return
    end

    local force = save_result and save_result.force == true

    -- Cerrar paneles antes de mksession para no persistir sus huecos.
    M.close_opencode()
    M.close_nvim_tree()
    M.close_aerial()

    vim.cmd("mksession! " .. vim.fn.fnameescape(session))

    -- Solo se persiste el estado si el guardado fue aceptado o rechazado explícitamente.
    M.save_state(state)

    if force then
      vim.cmd("restart +qall! source " .. vim.fn.fnameescape(session))
    else
      vim.cmd("restart source " .. vim.fn.fnameescape(session))
    end
  end)()
end

-- function M.setup()
--   vim.api.nvim_create_user_command("Re", function()
--     M.restart()
--   end, { desc = "hzsr: Previous" })
--
--   vim.keymap.set("n", "<A-r>", function()
--     M.restart()
--   end, { desc = "hzsr: Restart" })
-- end

return M
