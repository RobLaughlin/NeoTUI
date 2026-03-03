local M = {}

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

local function build_document(bufnr, prompt)
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

function M.prompt_and_insert()
  vim.ui.input({ prompt = "AI prompt > " }, function(input)
    local prompt = vim.trim(input or "")
    if prompt == "" then
      return
    end

    local ok_codeium, codeium = pcall(require, "codeium")
    local ok_api, codeium_api = pcall(require, "codeium.api")
    if not ok_codeium or not ok_api or not codeium.s then
      vim.notify("Codeium is not ready. Restart nvim and run :Codeium Auth if needed.", vim.log.levels.WARN)
      return
    end

    local status = codeium_api.check_status()
    if status and status.api_key_error then
      vim.notify("Codeium is not authenticated. Run :Codeium Auth.", vim.log.levels.WARN)
      return
    end

    if not codeium.s.port then
      vim.notify("Codeium server is still starting. Try again in a moment.", vim.log.levels.WARN)
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local target_cursor = vim.api.nvim_win_get_cursor(0)
    local document, editor_options, other_documents = build_document(bufnr, prompt)
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
      if generated == "" then
        vim.schedule(function()
          vim.notify("No AI code generated for that prompt.", vim.log.levels.INFO)
        end)
        return
      end

      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        local insert_lines = vim.split(generated, "\n", { plain = true })
        vim.api.nvim_buf_set_text(bufnr, target_cursor[1] - 1, target_cursor[2], target_cursor[1] - 1, target_cursor[2], insert_lines)
      end)
    end)
  end)
end

return M
