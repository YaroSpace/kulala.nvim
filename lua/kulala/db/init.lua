local CONFIG = require("kulala.config")

local M = {}

M.data = nil
M.global_data = {}

local function default_data()
  return {
    selected_env = nil, -- string - name of selected env
    http_client_env = nil, -- table of envs from http-client.env.json
    http_client_env_shared = nil, -- table of base env values which should be applied to all requests
    env = {}, -- table of envs from document sources
    scope_nr = nil, -- number - buffer number of the current scope
  }
end

local function get_current_scope_nr()
  if CONFIG.get().environment_scope == "b" then
    return M.current_buffer
  elseif CONFIG.get().environment_scope == "g" then
    return 0
  end
end

local function load_data()
  if CONFIG.get().environment_scope == "b" then
    local status, buf_data = pcall(vim.api.nvim_buf_get_var, M.current_buffer, "kulala_data")
    M.data = status and buf_data or default_data()
  elseif CONFIG.get().environment_scope == "g" then
    -- keep in lua only
    if not M.data then
      M.data = default_data()
    end
  end
  M.data.scope_nr = get_current_scope_nr()
end

local function save_data()
  if CONFIG.get().environment_scope == "b" then
    if vim.fn.bufexists(M.data.scope_nr) > 0 then
      vim.api.nvim_buf_set_var(M.data.scope_nr, "kulala_data", M.data)
    end
  elseif CONFIG.get().environment_scope == "g" then
    -- keep in lua only
  end
end

M.global_find_many = function()
  return M.global_data
end

M.global_find_unique = function(key)
  return M.global_data[key]
end

M.global_update = function()
  return M.global_data
end

M.find_many = function()
  if not M.data or not M.data.scope_nr then
    load_data()
  elseif M.data.scope_nr ~= get_current_scope_nr() then
    save_data()
    load_data()
  end
  if
    false
    and M.data
    and M.data.current_request
    and M.data.current_request.show_icon_line_number < 40
    and #require("kulala.cmd").tasks > 0
  then
    LOG.clean(M.data.current_request.environment)
    -- LOG(M.data.current_request.show_icon_line_number)
  end
  return M.data
end

M.update = function()
  return M.find_many()
end

M.find_unique = function(key)
  return M.find_many()[key]
end

return M
