-- sample file for the cmdline.nvim demo
local M = {}

function M.greet(name)
  return 'Hello, ' .. name .. '!'
end

function M.sum(list)
  local total = 0
  for _, v in ipairs(list) do
    total = total + v
  end
  return total
end

return M
