-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: module paths renamed from noice to cmdline.
local lazy = require("neat.cmdline.util.lazy")

---@module "neat.cmdline.util.ffi"
local ffi = lazy("neat.cmdline.util.ffi")

local M = {}

---@class neat.cmdline.HLAttrs
---@field rgb_ae_attr number
---@field rgb_fg_color number
---@field rgb_bg_color number
---@field rgb_sp_color number
---@field hl_blend number

function M.setup()
  M.attr2entry = ffi.syn_attr2entry --[[@as fun(attr: number): neat.cmdline.HLAttrs]]

  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      M.hl = {}
      for attr_id in pairs(M.hl_attrs) do
        M._create_hl(attr_id)
      end
    end,
  })
end

---@param attr_id number
---@return neat.cmdline.HLAttrs
function M.attr2entry(attr_id)
  M.setup()
  return M.attr2entry(attr_id)
end

---@type table<number, number>
M.hl = {}

---@type table<integer, vim.api.keyset.highlight> attribute id -> highlight
M.hl_attrs = {}

---@type table<number, number>
M.queue = {}

--- The highlight group for a `msg_show`/`cmdline_show` attribute id.
---@param attr_id integer
---@return string
function M.get_hl_group(attr_id)
  if attr_id == 0 then
    return "Normal"
  end
  M.queue[attr_id] = attr_id
  return "NeatAttr" .. tostring(attr_id)
end

function M.update()
  for attr_id, _ in pairs(M.queue) do
    M._create_hl(attr_id)
  end
  M.queue = {}
end

---@param attr_id integer
function M._create_hl(attr_id)
  if attr_id == 0 then
    return
  end
  if not M.hl_attrs[attr_id] then
    local attrs = M.attr2entry(attr_id)
    M.hl_attrs[attr_id] = {
      fg = attrs.rgb_fg_color,
      bg = attrs.rgb_bg_color,
      sp = attrs.rgb_sp_color,
      bold = bit.band(attrs.rgb_ae_attr, 0x02) ~= 0,
      standout = bit.band(attrs.rgb_ae_attr, 0x0100) ~= 0,
      italic = bit.band(attrs.rgb_ae_attr, 0x04) ~= 0,
      underline = bit.band(attrs.rgb_ae_attr, 0x08) ~= 0,
      undercurl = bit.band(attrs.rgb_ae_attr, 0x10) ~= 0,
      nocombine = bit.band(attrs.rgb_ae_attr, 0x0200) ~= 0,
      reverse = bit.band(attrs.rgb_ae_attr, 0x01) ~= 0,
      blend = attrs.hl_blend ~= -1 and attrs.hl_blend or nil,
    }
  end
  if not M.hl[attr_id] then
    local hl_group = M.get_hl_group(attr_id)
    vim.api.nvim_set_hl(0, hl_group, M.hl_attrs[attr_id])
    M.hl[attr_id] = attr_id
  end
end

return M
