local M = {}

local function state_root()
  return vim.env.XDG_STATE_HOME or vim.fn.stdpath("state")
end

local function flag_enabled(flag_name)
  local path = state_root() .. "/nvim/" .. flag_name
  return vim.fn.filereadable(path) ~= 1
end

local function is_wsl2()
  local osrelease_path = "/proc/sys/kernel/osrelease"
  if vim.fn.filereadable(osrelease_path) ~= 1 then
    return false
  end

  local ok, lines = pcall(vim.fn.readfile, osrelease_path)
  if not ok or #lines == 0 then
    return false
  end

  local osrelease = string.lower(lines[1])
  if osrelease:find("microsoft", 1, true) ~= nil and osrelease:find("wsl2", 1, true) ~= nil then
    return true
  end

  return vim.env.WSL_INTEROP ~= nil and vim.env.WSL_INTEROP ~= ""
end

local function configure_wsl_clipboard_provider()
  if vim.fn.executable("win32yank.exe") == 1 then
    vim.g.clipboard = {
      name = "NeoTUI WSL2 clipboard",
      copy = {
        ["+"] = { "win32yank.exe", "-i", "--crlf" },
        ["*"] = { "win32yank.exe", "-i", "--crlf" },
      },
      paste = {
        ["+"] = { "win32yank.exe", "-o", "--lf" },
        ["*"] = { "win32yank.exe", "-o", "--lf" },
      },
      cache_enabled = 0,
    }
    return true
  end

  if vim.fn.executable("clip.exe") == 1 and vim.fn.executable("powershell.exe") == 1 then
    vim.g.clipboard = {
      name = "NeoTUI WSL2 clipboard",
      copy = {
        ["+"] = { "clip.exe" },
        ["*"] = { "clip.exe" },
      },
      paste = {
        ["+"] = {
          "powershell.exe",
          "-NoProfile",
          "-Command",
          "[Console]::Out.Write((Get-Clipboard -Raw) -replace \"`r\", \"\")",
        },
        ["*"] = {
          "powershell.exe",
          "-NoProfile",
          "-Command",
          "[Console]::Out.Write((Get-Clipboard -Raw) -replace \"`r\", \"\")",
        },
      },
      cache_enabled = 0,
    }
    return true
  end

  return false
end

function M.setup()
  if not flag_enabled("clipboard-sharing-disabled") then
    return
  end

  vim.opt.clipboard = "unnamedplus"

  if not is_wsl2() then
    return
  end

  if not flag_enabled("wsl-host-clipboard-disabled") then
    return
  end

  configure_wsl_clipboard_provider()
end

return M
