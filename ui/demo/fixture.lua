-- Demo fixture for the review tapes: nested blocks for the indent guides and one
-- unused local so `gra` has code actions to offer.
local M = {}

function M.walk(tree, visit)
  local unused = 0
  for _, node in ipairs(tree) do
    if node.children then
      for _, child in ipairs(node.children) do
        if visit(child) then
          M.walk(child.children or {}, visit)
        end
      end
    else
      visit(node)
    end
  end
end

function M.count(tree)
  local n = 0
  M.walk(tree, function()
    n = n + 1
    return true
  end)
  return n
end

return M
