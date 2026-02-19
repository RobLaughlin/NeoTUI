-- ============================================================
-- Diagnostics Sync to lf (file manager)
--
-- Writes LSP diagnostics to a cache file for lf to display.
-- Updates on every diagnostic change (real-time as you type).
-- ============================================================

local M = {}

local CACHE_DIR = vim.fn.stdpath("data")
local CACHE_FILE = CACHE_DIR .. "/diagnostics.json"
local DEBOUNCE_MS = 100

local timer = nil
local last_diagnostics = {}

local function ensure_cache_dir()
  if vim.fn.isdirectory(CACHE_DIR) == 0 then
    vim.fn.mkdir(CACHE_DIR, "p")
  end
end

local function get_severity(diagnostics)
  if not diagnostics or #diagnostics == 0 then
    return nil
  end
  local has_error = false
  for _, d in ipairs(diagnostics) do
    if d.severity == vim.diagnostic.severity.ERROR then
      has_error = true
      break
    end
  end
  return has_error and "error" or "warning"
end

local function write_diagnostics_cache()
  ensure_cache_dir()
  local result = {}
  for path, severity in pairs(last_diagnostics) do
    if severity then
      result[path] = severity
    end
  end
  local json = vim.json.encode(result)
  local file = io.open(CACHE_FILE, "w")
  if file then
    file:write(json)
    file:close()
    vim.system({ "lf", "-remote", "send reload" }, { detach = true })
  end
end

local function sync_all_diagnostics()
  last_diagnostics = {}
  local all_bufs = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(all_bufs) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local path = vim.api.nvim_buf_get_name(bufnr)
      if path and path ~= "" then
        local diagnostics = vim.diagnostic.get(bufnr)
        local severity = get_severity(diagnostics)
        if severity then
          last_diagnostics[path] = severity
        end
      end
    end
  end
  write_diagnostics_cache()
end

local function debounced_sync()
  if timer then
    timer:stop()
    timer:close()
  end
  timer = vim.defer_fn(sync_all_diagnostics, DEBOUNCE_MS)
end

function M.setup()
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    callback = debounced_sync,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufUnload" }, {
    callback = debounced_sync,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      ensure_cache_dir()
      os.remove(CACHE_FILE)
      vim.system({ "lf", "-remote", "send reload" }, { detach = true })
    end,
  })
end

M.setup()

return M
