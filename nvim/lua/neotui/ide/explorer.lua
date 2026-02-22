local M = {
  sticky_visible = false,
  last_path = nil,
}

local function maybe_set_last_path(path)
  if type(path) ~= "string" or path == "" then
    return
  end
  M.last_path = vim.fn.fnamemodify(path, ":p")
end

local function current_file_path()
  if vim.bo.filetype == "neo-tree" then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil
  end
  return vim.fn.fnamemodify(name, ":p")
end

function M.capture_from_current_buffer()
  maybe_set_last_path(current_file_path())
end

function M.capture_from_neotree_cursor()
  local ok_manager, manager = pcall(require, "neo-tree.sources.manager")
  if not ok_manager then
    return
  end

  local state = manager.get_state("filesystem")
  if not state or not state.tree then
    return
  end

  local ok_node, node = pcall(state.tree.get_node, state.tree)
  if not ok_node or not node or node.type ~= "file" then
    return
  end

  maybe_set_last_path(node:get_id())
end

function M.show_left()
  local target = M.last_path or current_file_path()
  if target and target ~= "" then
    vim.cmd("Neotree filesystem show left reveal_file=" .. vim.fn.fnameescape(target))
  else
    vim.cmd("Neotree filesystem show left")
  end
end

function M.enable()
  M.sticky_visible = true
  M.show_left()
end

function M.disable()
  M.sticky_visible = false
  vim.cmd("Neotree close")
end

function M.toggle()
  if M.sticky_visible then
    M.disable()
  else
    M.enable()
  end
end

function M.on_tab_enter()
  if not M.sticky_visible then
    return
  end
  M.show_left()
end

function M.open_in_tab_and_sync(state)
  local tree = state.tree
  if not tree then
    return
  end

  local ok_node, node = pcall(tree.get_node, tree)
  if not ok_node or not node then
    return
  end

  local fs_commands = require("neo-tree.sources.filesystem.commands")
  if node.type == "file" then
    maybe_set_last_path(node:get_id())
  end

  fs_commands.open_tabnew(state)

  if node.type == "file" and M.sticky_visible then
    M.show_left()
  end
end

return M
