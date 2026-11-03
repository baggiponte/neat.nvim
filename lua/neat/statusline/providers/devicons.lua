-- Portions adapted from lualine.nvim (MIT) by hoob3rt and contributors; modified.
-- Source: lua/lualine/components/filetype.lua (icon lookup)
-- at nvim-lualine/lualine.nvim 221ce6b2d999187044529f49da6554a92f740a96.
-- Changes: a neat.statusline.IconProvider.
--
-- The `devicons` icon provider: nvim-tree/nvim-web-devicons.

local devicons ---@type table? the nvim-web-devicons module, once loaded

---@type neat.statusline.IconProvider
return {
  load = function()
    local ok, mod = pcall(require, 'nvim-web-devicons')
    devicons = ok and mod or nil
    return devicons ~= nil
  end,
  -- Same lookup as lualine's filetype component: by file name, then by
  -- filetype, then devicons' generic icon.
  get = function(name, filetype)
    if not devicons then
      return nil
    end
    local icon, group = devicons.get_icon(name)
    if icon == nil then
      icon, group = devicons.get_icon_by_filetype(filetype)
    end
    if icon == nil and group == nil then
      return '\u{e612}', 'DevIconDefault'
    end
    return icon, group
  end,
}
