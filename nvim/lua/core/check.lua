-- ============================================================
-- :Check command - Project-wide linting with gitignore support
-- ============================================================
local M = {}

local function parse_gitignore(gitignore_path)
  local patterns = {}
  local file = io.open(gitignore_path, "r")
  if not file then return patterns end
  for line in file:lines() do
    if line ~= "" and not line:match("^#") then
      table.insert(patterns, line)
    end
  end
  file:close()
  return patterns
end

local function matches_gitignore(path, patterns, root)
  local rel_path = path
  if root then
    rel_path = path:sub(#root + 2)
  end
  for _, pattern in ipairs(patterns) do
    local escaped = pattern:gsub("([%.%+%-%^%$%(%)%%])", "%%%1")
    escaped = escaped:gsub("%*", ".*")
    escaped = escaped:gsub("%?", ".")
    if rel_path:match(escaped) or rel_path:match(".*/" .. escaped) then
      return true
    end
    if rel_path:match("^" .. escaped .. "$") then
      return true
    end
  end
  return false
end

local function get_files_recursive(root, gitignore_patterns)
  local files = {}
  local dirs_to_scan = { root }
  local seen_dirs = {}
  while #dirs_to_scan > 0 do
    local dir = table.remove(dirs_to_scan)
    local handle = vim.loop.fs_scandir(dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        local full_path = dir .. "/" .. name
        if type == "directory" then
          if name ~= ".git" and not matches_gitignore(full_path, gitignore_patterns, root) then
            if not seen_dirs[full_path] then
              seen_dirs[full_path] = true
              table.insert(dirs_to_scan, full_path)
            end
          end
        elseif type == "file" then
          if not matches_gitignore(full_path, gitignore_patterns, root) then
            table.insert(files, full_path)
          end
        end
      end
    end
  end
  return files
end

local function get_linter_for_ft(ft)
  local linters = {
    terraform = "terraform",
    tf = "terraform",
    sh = "shellcheck",
    python = "ruff",
    javascript = "eslint",
    typescript = "eslint",
    go = "golangci-lint",
    lua = "luacheck",
  }
  return linters[ft]
end

local function run_linter(file)
  local ft = vim.filetype.match({ filename = file })
  if not ft then return nil, nil end
  local linter = get_linter_for_ft(ft)
  if not linter then return nil, nil end
  local cmd
  if linter == "terraform" then
    cmd = string.format("terraform validate -json %s 2>&1", vim.fn.shellescape(file))
  elseif linter == "shellcheck" then
    cmd = string.format("shellcheck -f json %s 2>&1", vim.fn.shellescape(file))
  elseif linter == "ruff" then
    cmd = string.format("ruff check --output-format=json %s 2>&1", vim.fn.shellescape(file))
  elseif linter == "eslint" then
    cmd = string.format("npx eslint --format=json %s 2>&1", vim.fn.shellescape(file))
  elseif linter == "golangci-lint" then
    cmd = string.format("golangci-lint run --out-format=json %s 2>&1", vim.fn.shellescape(file))
  elseif linter == "luacheck" then
    cmd = string.format("luacheck --formatter=json %s 2>&1", vim.fn.shellescape(file))
  else
    return nil, nil
  end
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error
  local has_errors = false
  local has_warnings = false
  if exit_code ~= 0 and output ~= "" then
    local ok, parsed = pcall(vim.json.decode, output)
    if ok and parsed then
      if type(parsed) == "table" then
        if parsed.diagnostics or parsed[1] then
          has_errors = true
        end
        if parsed.warnings then
          has_warnings = true
        end
      end
    else
      if output:match("[Ee]rror") or output:match("[Ff]ailed") then
        has_errors = true
      elseif output:match("[Ww]arn") or output:match("[Hh]int") then
        has_warnings = true
      end
    end
  end
  return has_errors, has_warnings
end

local function display_results(results, root)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = { "# Lint Check Results", "# Directory: " .. root, "" }
  local ns = vim.api.nvim_create_namespace("CheckResults")
  local error_count = 0
  local warning_count = 0
  local sorted = {}
  for path, status in pairs(results) do
    table.insert(sorted, { path = path, status = status })
  end
  table.sort(sorted, function(a, b) return a.path < b.path end)
  local extmark_id = 0
  for _, item in ipairs(sorted) do
    local rel_path = item.path:sub(#root + 2)
    local status = item.status
    local line_data
    if status == "error" then
      line_data = "  ✗ " .. rel_path
      error_count = error_count + 1
    elseif status == "warning" then
      line_data = "  ⚠ " .. rel_path
      warning_count = warning_count + 1
    elseif status == "ok" then
      line_data = "  ✓ " .. rel_path
    else
      line_data = "  · " .. rel_path
    end
    table.insert(lines, line_data)
    local line_num = #lines - 1
    local hl_group
    if status == "error" then
      hl_group = "DiagnosticError"
    elseif status == "warning" then
      hl_group = "DiagnosticWarn"
    elseif status == "ok" then
      hl_group = "DiagnosticOk"
    else
      hl_group = "Comment"
    end
    vim.api.nvim_buf_set_extmark(buf, ns, line_num, 0, {
      id = extmark_id,
      hl_group = hl_group,
      end_col = #line_data,
    })
    extmark_id = extmark_id + 1
  end
  table.insert(lines, "")
  table.insert(lines, string.format("# Summary: %d errors, %d warnings", error_count, warning_count))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "check-results")
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(30, vim.o.lines - 4)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
    title = " Check Results ",
    title_pos = "center",
  })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close check results" })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, desc = "Close check results" })
end

function M.check()
  local root = vim.fn.getcwd()
  local gitignore_path = root .. "/.gitignore"
  local gitignore_patterns = parse_gitignore(gitignore_path)
  local files = get_files_recursive(root, gitignore_patterns)
  local results = {}
  local total = #files
  if total == 0 then
    vim.notify("No files to check", vim.log.levels.INFO)
    return
  end
  vim.notify(string.format("Checking %d files...", total), vim.log.levels.INFO)
  for i, file in ipairs(files) do
    local rel = file:sub(#root + 2)
    vim.notify(string.format("[%d/%d] Checking %s", i, total, rel), vim.log.levels.INFO)
    local has_errors, has_warnings = run_linter(file)
    if has_errors then
      results[file] = "error"
    elseif has_warnings then
      results[file] = "warning"
    elseif has_errors == false and has_warnings == false then
      results[file] = "ok"
    else
      results[file] = "skipped"
    end
  end
  display_results(results, root)
end

vim.api.nvim_create_user_command("Check", function()
  M.check()
end, { desc = "Run project-wide lint check respecting .gitignore" })

return M
