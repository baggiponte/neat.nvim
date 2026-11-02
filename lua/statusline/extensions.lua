-- Adapted from lualine.nvim (MIT) by hoob3rt and contributors; modified.
-- Source: lua/lualine/extensions/{lazy,man,neo-tree,oil,quickfix}.lua
-- at nvim-lualine/lualine.nvim 221ce6b2d999187044529f49da6554a92f740a96.
-- Changes: expressed as statusline.nvim section tables keyed by filetype.

-- Special-window layouts by filetype. Behaviour mirrors the lualine
-- extensions the replaced config used (lazy, man, neo-tree, oil, quickfix).
local c = require('statusline.components')

local M = {}

local function short_cwd()
  return c.escape(vim.fn.fnamemodify(vim.fn.getcwd(), ':~'))
end

local function is_loclist(ctx)
  return vim.fn.getloclist(ctx.win, { filewinid = 1 }).filewinid ~= 0
end

M.builtin = {
  lazy = {
    a = {
      function()
        return 'lazy 💤'
      end,
    },
    b = {
      function()
        local ok, lazy = pcall(require, 'lazy')
        if not ok then
          return ''
        end
        local s = lazy.stats()
        return 'loaded: ' .. s.loaded .. '/' .. s.count
      end,
    },
    c = {
      function()
        local ok, status = pcall(require, 'lazy.status')
        if ok and status.has_updates() then
          return c.escape(status.updates())
        end
        return ''
      end,
    },
  },

  man = {
    a = {
      function()
        return 'MAN'
      end,
    },
    b = {
      function(ctx)
        return require('statusline.cache').file(ctx.buf).name
      end,
    },
    y = { 'progress' },
    z = { 'location' },
  },

  ['neo-tree'] = {
    a = { short_cwd },
  },

  oil = {
    a = {
      function(ctx)
        local ok, oil = pcall(require, 'oil')
        if not ok then
          return ''
        end
        local dir = oil.get_current_dir(ctx.buf)
        return dir and c.escape(vim.fn.fnamemodify(dir, ':~')) or ''
      end,
    },
  },

  qf = {
    a = {
      function(ctx)
        return is_loclist(ctx) and 'Location List' or 'Quickfix List'
      end,
    },
    b = {
      function(ctx)
        local t = is_loclist(ctx) and vim.fn.getloclist(ctx.win, { title = 0 }).title
          or vim.fn.getqflist({ title = 0 }).title
        return c.escape(t or '')
      end,
    },
    z = { 'location' },
  },
}

return M
