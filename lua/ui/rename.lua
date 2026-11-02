-- Adapted from snacks.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Source: lua/snacks/rename.lua (`on_rename_file`) at folke/snacks.nvim v2.22.0
-- (5eac729fa290248acfe10916d92a5ed5e5c0f9ed).
-- Changes: kept only the LSP notification used by file explorers; `rename_file` and the buffer swap are gone.

local M = {}

--- Tell LSP clients that a file moved: `workspace/willRenameFiles` (applying any edits) before the move,
--- `workspace/didRenameFiles` after it. Call it from a file explorer's rename/move event.
---@param from string
---@param to string
---@param rename? fun() performs the move, when the caller has not done it yet
function M.on_rename_file(from, to, rename)
  local changes = { files = { { oldUri = vim.uri_from_fname(from), newUri = vim.uri_from_fname(to) } } }
  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client:supports_method("workspace/willRenameFiles") then
      local resp = client:request_sync("workspace/willRenameFiles", changes, 1000, 0)
      if resp and resp.result ~= nil then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end
  if rename then
    rename()
  end
  for _, client in ipairs(clients) do
    if client:supports_method("workspace/didRenameFiles") then
      client:notify("workspace/didRenameFiles", changes)
    end
  end
end

return M
