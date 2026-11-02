-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the `message` and `text` formatters are left.
local M = {}

---@param message NoiceMessage
---@param input NoiceMessage
---@param opts NoiceFormatOptions.message
function M.message(message, opts, input)
  if opts.hl_group then
    message:append(input:content(), opts.hl_group)
  else
    message:append(input)
  end
end

---@param message NoiceMessage
---@param opts NoiceFormatOptions.text
function M.text(message, opts)
  if opts.text and opts.text ~= "" then
    message:append(opts.text, opts.hl_group)
  end
end

return M
