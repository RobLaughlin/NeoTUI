local M = {}

local PROVIDERS = { "opencode", "codeium" }
local DEFAULT_PROVIDER = "codeium"
local OPENCODE_DEFAULT_MODEL = "openai/gpt-5.3-codex"
local OPENCODE_FILE_SESSIONS_FILE = "ai-opencode-file-sessions.json"
local STATE_ROOT = (vim.uv and vim.uv.os_getenv and vim.uv.os_getenv("XDG_STATE_HOME")) or os.getenv("XDG_STATE_HOME") or vim.fn.stdpath("state")
local STATE_DIR = STATE_ROOT .. "/nvim"
local opencode_buffer_sessions = {}
local decode_json

local function state_root()
  return STATE_ROOT
end

local function state_dir()
  vim.fn.mkdir(STATE_DIR, "p")
  return STATE_DIR
end

local function state_file(name)
  return state_dir() .. "/" .. name
end

local function read_state(name)
  local path = state_file(name)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  local lines = vim.fn.readfile(path)
  if #lines == 0 then
    return nil
  end
  local value = vim.trim(lines[1] or "")
  if value == "" then
    return nil
  end
  return value
end

local function write_state(name, value)
  vim.fn.writefile({ value }, state_file(name))
end

local function read_json_state(name)
  local path = state_file(name)
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end

  local raw = table.concat(vim.fn.readfile(path), "\n")
  if vim.trim(raw) == "" then
    return {}
  end

  local decoded = decode_json(raw)
  if type(decoded) ~= "table" then
    return {}
  end

  local out = {}
  for key, value in pairs(decoded) do
    if type(key) == "string" and type(value) == "string" and value ~= "" then
      out[key] = value
    end
  end
  return out
end

local function write_json_state(name, value)
  local encoded = vim.json.encode(value or {})
  vim.fn.writefile(vim.split(encoded, "\n", { plain = true }), state_file(name))
end

local function get_buf_file_key(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  local absolute = vim.fn.fnamemodify(name, ":p")
  if absolute == "" then
    return nil
  end

  return absolute
end

local function get_opencode_session_for_buffer(bufnr)
  local file_key = get_buf_file_key(bufnr)
  if not file_key then
    return opencode_buffer_sessions[bufnr], nil
  end

  local file_sessions = read_json_state(OPENCODE_FILE_SESSIONS_FILE)
  return file_sessions[file_key], file_key
end

local function set_opencode_session_for_buffer(bufnr, file_key, session_id)
  if not session_id or session_id == "" then
    return
  end

  if not file_key then
    opencode_buffer_sessions[bufnr] = session_id
    return
  end

  local file_sessions = read_json_state(OPENCODE_FILE_SESSIONS_FILE)
  file_sessions[file_key] = session_id
  write_json_state(OPENCODE_FILE_SESSIONS_FILE, file_sessions)
end

local function clear_opencode_file_sessions()
  opencode_buffer_sessions = {}
  local path = state_file(OPENCODE_FILE_SESSIONS_FILE)
  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

local function provider_is_valid(provider)
  for _, value in ipairs(PROVIDERS) do
    if value == provider then
      return true
    end
  end
  return false
end

local function get_active_provider()
  local stored = read_state("ai-prompt-provider")
  if stored and provider_is_valid(stored) then
    return stored
  end
  return DEFAULT_PROVIDER
end

local function set_active_provider(provider)
  if not provider_is_valid(provider) then
    return false
  end
  write_state("ai-prompt-provider", provider)
  return true
end

local function get_model(provider)
  if provider == "opencode" then
    return read_state("ai-model-opencode") or OPENCODE_DEFAULT_MODEL
  end
  return "auto/default"
end

local function set_model(provider, model)
  local normalized = vim.trim(model or "")
  if normalized == "" then
    return false
  end
  if provider == "opencode" then
    write_state("ai-model-opencode", normalized)
    return true
  end
  return false
end

decode_json = function(data)
  if not data or data == "" then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, data)
  if not ok then
    return nil
  end
  return decoded
end

local function strip_code_fences(text)
  local trimmed = vim.trim(text or "")
  if trimmed:sub(1, 3) ~= "```" then
    return trimmed
  end

  local lines = vim.split(trimmed, "\n", { plain = true })
  if #lines == 0 then
    return ""
  end

  if lines[1]:match("^```") then
    table.remove(lines, 1)
  end
  if #lines > 0 and lines[#lines]:match("^```") then
    table.remove(lines, #lines)
  end

  return vim.trim(table.concat(lines, "\n"))
end

local function insert_generated(bufnr, target_cursor, generated)
  local cleaned = strip_code_fences(generated)
  if cleaned == "" then
    vim.notify("No AI code generated for that prompt.", vim.log.levels.INFO)
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local insert_lines = vim.split(cleaned, "\n", { plain = true })
  vim.api.nvim_buf_set_text(bufnr, target_cursor[1] - 1, target_cursor[2], target_cursor[1] - 1, target_cursor[2], insert_lines)
end

local function get_comment_prefix(filetype)
  local prefixes = {
    lua = "--",
    vim = '"',
    python = "#",
    sh = "#",
    bash = "#",
    zsh = "#",
    ruby = "#",
    perl = "#",
    yaml = "#",
    toml = "#",
    make = "#",
    c = "//",
    cpp = "//",
    objc = "//",
    objcpp = "//",
    java = "//",
    javascript = "//",
    typescript = "//",
    javascriptreact = "//",
    typescriptreact = "//",
    go = "//",
    rust = "//",
    swift = "//",
    kotlin = "//",
    php = "//",
    cs = "//",
  }

  return prefixes[filetype] or "#"
end

local function build_codeium_document(bufnr, prompt)
  local ok_enums, enums = pcall(require, "codeium.enums")
  local ok_util, util = pcall(require, "codeium.util")
  if not ok_enums or not ok_util then
    return nil, nil, nil
  end

  local filetype = vim.bo[bufnr].filetype
  local language_key = enums.filetype_aliases[filetype] or (filetype == "" and "unspecified" or filetype)
  local language = enums.languages[language_key] or enums.languages.unspecified
  local editor_language = filetype == "" and "unspecified" or filetype
  local line_ending = util.get_newline(bufnr)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row, false)
  if #lines == 0 then
    lines = { "" }
  end

  local current = lines[#lines]
  lines[#lines] = current:sub(1, col)

  local comment = get_comment_prefix(filetype)
  local marker = comment .. " Generate code: " .. prompt
  lines[#lines + 1] = marker
  lines[#lines + 1] = ""

  local text = table.concat(lines, line_ending)
  local document = {
    text = text,
    editor_language = editor_language,
    language = language,
    cursor_position = { row = #lines - 1, col = 0 },
    absolute_uri = util.get_uri(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")),
    workspace_uri = util.get_uri(util.get_project_root()),
    line_ending = line_ending,
  }

  local editor_options = util.get_editor_options(bufnr)
  local other_documents = util.get_other_documents(bufnr)

  return document, editor_options, other_documents
end

local function prompt_with_context(bufnr, target_cursor, user_prompt)
  local filetype = vim.bo[bufnr].filetype
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local row = target_cursor[1]
  local col = target_cursor[2]
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local start_row = math.max(1, row - 80)
  local end_row = math.min(line_count, row + 80)
  local context_lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  local context_text = table.concat(context_lines, "\n")

  local message = {
    "You are generating code to insert at the cursor.",
    "Return only raw code with no markdown fences and no prose.",
    "If unsure, return the best small code snippet that matches the prompt.",
    "",
    "Prompt:",
    user_prompt,
    "",
    "File:",
    filename == "" and "[No Name]" or filename,
    "",
    "Filetype:",
    filetype == "" and "unspecified" or filetype,
    "",
    string.format("Cursor location: line %d, column %d", row, col),
    string.format("Context window: lines %d-%d", start_row, end_row),
    "",
    "Context:",
    context_text,
  }

  return table.concat(message, "\n")
end

local function opencode_available()
  if vim.fn.executable("opencode") == 1 then
    return true
  end
  local fallback = vim.fn.expand("~/.opencode/bin/opencode")
  return vim.fn.executable(fallback) == 1
end

local function opencode_cmd()
  if vim.fn.executable("opencode") == 1 then
    return "opencode"
  end
  local fallback = vim.fn.expand("~/.opencode/bin/opencode")
  if vim.fn.executable(fallback) == 1 then
    return fallback
  end
  return nil
end

local function opencode_auth_status(callback)
  local cmd = opencode_cmd()
  if not cmd then
    vim.schedule(function()
      callback(false, "opencode command not found")
    end)
    return
  end

  vim.system({ cmd, "auth", "list" }, { text = true }, function(result)
    if result.code ~= 0 then
      local stderr = vim.trim(result.stderr or "")
      vim.schedule(function()
        callback(false, stderr ~= "" and stderr or "opencode auth list failed")
      end)
      return
    end
    local out = result.stdout or ""
    local credentials = out:match("(%d+)%s+credentials")
    if credentials and tonumber(credentials) and tonumber(credentials) > 0 then
      vim.schedule(function()
        callback(true, out)
      end)
      return
    end
    vim.schedule(function()
      callback(false, out)
    end)
  end)
end

local function codeium_is_ready()
  local ok_codeium, codeium = pcall(require, "codeium")
  local ok_api, codeium_api = pcall(require, "codeium.api")
  if not ok_codeium or not ok_api or not codeium.s then
    return false
  end
  local status = codeium_api.check_status()
  if status and status.api_key_error then
    return false
  end
  if not codeium.s.port then
    return false
  end
  return true
end

local function model_parts(model)
  local provider, name = model:match("^([^/]+)/(.+)$")
  if provider and name then
    return provider, name
  end
  return "opencode", model
end

local function prompt_label(callback)
  local provider = get_active_provider()
  if provider == "codeium" then
    if codeium_is_ready() then
      callback("AI prompt (codeium) > ")
    else
      callback("AI prompt (unauthenticated) > ")
    end
    return
  end

  opencode_auth_status(function(authenticated)
    if not authenticated then
      callback("AI prompt (unauthenticated) > ")
      return
    end
    local model = get_model("opencode")
    local model_provider, model_name = model_parts(model)
    callback("AI prompt (" .. model_provider .. ") (" .. model_name .. ") > ")
  end)
end

local function codeium_prompt_insert(prompt, bufnr, target_cursor)
  local ok_codeium, codeium = pcall(require, "codeium")
  local ok_api, codeium_api = pcall(require, "codeium.api")
  if not ok_codeium or not ok_api or not codeium.s then
    vim.notify("Codeium is not ready. Restart nvim and run :Codeium Auth. Switch provider with :NeoTUIAIProvider or <leader>ap.", vim.log.levels.WARN)
    return
  end

  local status = codeium_api.check_status()
  if status and status.api_key_error then
    vim.notify("Codeium is not authenticated. Run :Codeium Auth. Switch provider with :NeoTUIAIProvider or <leader>ap.", vim.log.levels.WARN)
    return
  end

  if not codeium.s.port then
    vim.notify("Codeium server is still starting. Try again in a moment.", vim.log.levels.WARN)
    return
  end

  local document, editor_options, other_documents = build_codeium_document(bufnr, prompt)
  if not document then
    vim.notify("Failed to prepare Codeium prompt request.", vim.log.levels.ERROR)
    return
  end

  codeium.s:request_completion(document, editor_options, other_documents, function(success, response)
    if not success or not response or not response.completionItems or #response.completionItems == 0 then
      vim.schedule(function()
        vim.notify("No AI code generated for that prompt.", vim.log.levels.INFO)
      end)
      return
    end

    local generated = response.completionItems[1].completion and response.completionItems[1].completion.text or ""
    vim.schedule(function()
      insert_generated(bufnr, target_cursor, generated)
    end)
  end)
end

local function parse_opencode_output(stdout)
  local output = {}
  local session_id
  for _, line in ipairs(vim.split(stdout or "", "\n", { plain = true })) do
    if line ~= "" then
      local decoded = decode_json(line)
      if decoded then
        if type(decoded.sessionID) == "string" and decoded.sessionID ~= "" then
          session_id = decoded.sessionID
        end
        if decoded.part and type(decoded.part.sessionID) == "string" and decoded.part.sessionID ~= "" then
          session_id = decoded.part.sessionID
        end
        if decoded.type == "text" and decoded.part and decoded.part.text then
          table.insert(output, decoded.part.text)
        end
      end
    end
  end
  return table.concat(output, "\n"), session_id
end

local function opencode_prompt_insert(prompt, bufnr, target_cursor)
  local cmd = opencode_cmd()
  if not cmd then
    vim.notify("opencode is not installed. Install it or switch provider to codeium with :NeoTUIAIProvider.", vim.log.levels.WARN)
    return
  end

  opencode_auth_status(function(authenticated)
    if not authenticated then
      vim.schedule(function()
        vim.notify("OpenCode is not authenticated. Run :NeoTUIAIProvider and choose OpenCode login.", vim.log.levels.WARN)
      end)
      return
    end

    local model = get_model("opencode")
    local request_prompt = prompt_with_context(bufnr, target_cursor, prompt)
    local existing_session, file_key = get_opencode_session_for_buffer(bufnr)

    local function run_with_session(session_id, allow_retry)
      local args = {
        cmd,
        "run",
        request_prompt,
        "--format",
        "json",
        "-m",
        model,
      }

      if session_id and session_id ~= "" then
        table.insert(args, "--session")
        table.insert(args, session_id)
      end

      vim.system(args, { text = true }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            if allow_retry and session_id and session_id ~= "" then
              run_with_session(nil, false)
              return
            end

            local message = vim.trim(result.stderr or "")
            if message == "" then
              message = "opencode run failed"
            end
            vim.notify("OpenCode request failed: " .. message, vim.log.levels.ERROR)
            return
          end

          local generated, returned_session = parse_opencode_output(result.stdout)
          if returned_session and returned_session ~= "" then
            set_opencode_session_for_buffer(bufnr, file_key, returned_session)
          end
          insert_generated(bufnr, target_cursor, generated)
        end)
      end)
    end

    run_with_session(existing_session, true)
  end)
end

local function fetch_opencode_models(callback)
  local cmd = opencode_cmd()
  if not cmd then
    callback(false, "opencode command not found")
    return
  end

  vim.system({ cmd, "models" }, { text = true }, function(result)
    if result.code ~= 0 then
      local message = vim.trim(result.stderr or "")
      callback(false, message ~= "" and message or "opencode models failed")
      return
    end

    local models = {}
    local seen = {}
    for _, line in ipairs(vim.split(result.stdout or "", "\n", { plain = true })) do
      local item = vim.trim(line)
      if item ~= "" and not seen[item] then
        seen[item] = true
        table.insert(models, item)
      end
    end
    callback(true, models)
  end)
end

local function show_opencode_auth_status()
  opencode_auth_status(function(authenticated, output)
    vim.schedule(function()
      if authenticated then
        vim.notify("OpenCode auth: ready", vim.log.levels.INFO)
      else
        local tail = vim.trim(output or "")
        if tail == "" then
          tail = "No OpenCode credentials found."
        end
        vim.notify("OpenCode auth: unauthenticated\n" .. tail, vim.log.levels.WARN)
      end
    end)
  end)
end

local function start_opencode_login()
  local cmd = opencode_cmd()
  if not cmd then
    vim.notify("opencode is not installed. Install it and retry OpenCode login.", vim.log.levels.WARN)
    return
  end

  local tmux_env = (vim.uv and vim.uv.os_getenv and vim.uv.os_getenv("TMUX")) or os.getenv("TMUX") or ""
  if tmux_env ~= "" then
    vim.notify("Opening OpenCode login in a new tmux window.", vim.log.levels.INFO)
    local shell_cmd = string.format("%s auth login", vim.fn.shellescape(cmd))
    vim.system({ "tmux", "new-window", "-n", "opencode-auth", shell_cmd }, { text = true }, function(result)
      if result.code ~= 0 then
        vim.schedule(function()
          local message = vim.trim(result.stderr or "")
          if message == "" then
            message = "tmux new-window failed"
          end
          vim.notify("Failed to open tmux auth window: " .. message, vim.log.levels.ERROR)
        end)
      end
    end)
    return
  end

  vim.notify("Starting OpenCode login in nvim terminal split (tmux not detected).", vim.log.levels.INFO)
  vim.schedule(function()
    vim.cmd("botright 12split")
    vim.fn.termopen({ cmd, "auth", "login" })
    vim.cmd("startinsert")
  end)
end

function M.get_active_provider()
  return get_active_provider()
end

function M.get_active_model()
  return get_model(get_active_provider())
end

function M.show_status()
  local provider = get_active_provider()
  if provider == "codeium" then
    local auth = codeium_is_ready() and "ready" or "unauthenticated"
    vim.notify("AI prompt provider: codeium (model: auto/default)\nAuth: " .. auth .. "\nSwitch provider: :NeoTUIAIProvider / <leader>ap", vim.log.levels.INFO)
    return
  end

  opencode_auth_status(function(authenticated)
    vim.schedule(function()
      local auth = authenticated and "ready" or "unauthenticated"
      local model = get_model("opencode")
      local model_provider, model_name = model_parts(model)
      vim.notify("AI prompt provider: opencode\nModel route: " .. model_provider .. "/" .. model_name .. "\nAuth: " .. auth .. "\nSwitch provider: :NeoTUIAIProvider / <leader>ap\nChange model: :NeoTUIAIModel / <leader>am", vim.log.levels.INFO)
    end)
  end)
end

function M.select_provider()
  local options = {
    "Switch provider",
    "OpenCode login",
    "OpenCode auth status",
    "Clear OpenCode file sessions",
    "Show AI status",
  }

  vim.ui.select(options, {
    prompt = "NeoTUI AI provider/auth",
  }, function(choice)
    if not choice then
      return
    end

    if choice == "Switch provider" then
      vim.ui.select(PROVIDERS, {
        prompt = "Select AI prompt provider",
        format_item = function(item)
          if item == "opencode" then
            return "opencode (multi-provider auth/model routing)"
          end
          return "codeium (browser auth via :Codeium Auth)"
        end,
      }, function(provider_choice)
        if not provider_choice then
          return
        end

        if set_active_provider(provider_choice) then
          if provider_choice == "opencode" then
            vim.notify("AI prompt provider set to opencode. Use OpenCode login from :NeoTUIAIProvider if needed.", vim.log.levels.INFO)
          else
            vim.notify("AI prompt provider set to codeium. Run :Codeium Auth if needed.", vim.log.levels.INFO)
          end
        end
      end)
      return
    end

    if choice == "OpenCode login" then
      start_opencode_login()
      return
    end

    if choice == "OpenCode auth status" then
      show_opencode_auth_status()
      return
    end

    if choice == "Clear OpenCode file sessions" then
      clear_opencode_file_sessions()
      vim.notify("Cleared OpenCode file-scoped prompt sessions.", vim.log.levels.INFO)
      return
    end

    M.show_status()
  end)
end

function M.select_model()
  local provider = get_active_provider()
  if provider == "codeium" then
    vim.notify("Codeium prompt insertion uses auto/default model. Switch provider with :NeoTUIAIProvider or <leader>ap for model selection.", vim.log.levels.INFO)
    return
  end

  fetch_opencode_models(function(ok, data)
    vim.schedule(function()
      if not ok then
        vim.notify("Failed to load OpenCode models: " .. data, vim.log.levels.ERROR)
        return
      end

      local options = vim.deepcopy(data)
      table.insert(options, "Manual model id...")

      vim.ui.select(options, {
        prompt = "Select OpenCode model",
      }, function(choice)
        if not choice then
          return
        end

        if choice == "Manual model id..." then
          vim.ui.input({ prompt = "opencode model id > " }, function(input)
            local value = vim.trim(input or "")
            if value == "" then
              return
            end
            if set_model("opencode", value) then
              vim.notify("Set opencode model route to " .. value, vim.log.levels.INFO)
            end
          end)
          return
        end

        if set_model("opencode", choice) then
          vim.notify("Set opencode model route to " .. choice, vim.log.levels.INFO)
        end
      end)
    end)
  end)
end

function M.prompt_and_insert()
  local provider = get_active_provider()
  prompt_label(function(label)
    vim.schedule(function()
      vim.ui.input({ prompt = label }, function(input)
        local prompt = vim.trim(input or "")
        if prompt == "" then
          return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local target_cursor = vim.api.nvim_win_get_cursor(0)

        if provider == "codeium" then
          codeium_prompt_insert(prompt, bufnr, target_cursor)
        else
          opencode_prompt_insert(prompt, bufnr, target_cursor)
        end
      end)
    end)
  end)
end

return M
