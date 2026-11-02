-- Adapted from snacks.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Source: lua/snacks/init.lua (config helpers) + lua/snacks/util/init.lua
-- at folke/snacks.nvim v2.22.0 (5eac729fa290248acfe10916d92a5ed5e5c0f9ed).
-- Changes: merged the config helpers and the util subset used by win/input/notify/indent
-- into one module; removed everything else.

local M = {}

---@type table<string, table>
local config = { styles = {} }

--- Per-module user options (set by `require("ui").setup`).
M.config = setmetatable({}, {
  __index = function(_, k)
    config[k] = config[k] or {}
    return config[k]
  end,
  __newindex = function(_, k, v)
    config[k] = v
  end,
})

local function is_dict_like(v) -- has string and number keys
  return type(v) == "table" and (vim.tbl_isempty(v) or not vim.islist(v))
end
local function is_dict(v) -- has only string keys
  return type(v) == "table" and (vim.tbl_isempty(v) or not v[1])
end

--- Merges the values similar to vim.tbl_deep_extend with the **force** behavior,
--- but the values can be any type
function M.merge(...)
  local ret = select(1, ...)
  for i = 2, select("#", ...) do
    local value = select(i, ...)
    if is_dict_like(ret) and is_dict(value) then
      for k, v in pairs(value) do
        ret[k] = M.merge(ret[k], v)
      end
    elseif value ~= nil then
      ret = value
    end
  end
  return ret
end

---@generic T: table
---@param name string
---@param defaults T
---@param ... T[]
---@return T
function M.get(name, defaults, ...)
  local merge, todo = {}, { defaults, config[name] or {}, ... }
  for i = 1, select("#", ...) + 2 do
    local v = todo[i]
    if type(v) == "table" then
      table.insert(merge, vim.deepcopy(v))
    end
  end
  return M.merge(unpack(merge))
end

--- Register a window style config.
---@param name string
---@param defaults table
function M.style(name, defaults)
  config.styles[name] = vim.tbl_deep_extend("force", vim.deepcopy(defaults), config.styles[name] or {})
  return name
end

function M.styles()
  return config.styles
end

local hl_groups = {} ---@type table<string, vim.api.keyset.highlight>
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("ui_util_hl", { clear = true }),
  callback = function()
    for hl_group, hl in pairs(hl_groups) do
      vim.api.nvim_set_hl(0, hl_group, hl)
    end
  end,
})

local langs = {} ---@type table<string, boolean>

---@param lang string|number|nil
---@return string?
function M.get_lang(lang)
  lang = type(lang) == "number" and vim.bo[lang].filetype or lang --[[@as string?]]
  lang = lang and vim.treesitter.language.get_lang(lang) or lang
  if lang and lang ~= "" and langs[lang] == nil then
    local ok, ret = pcall(vim.treesitter.language.add, lang)
    langs[lang] = ok and ret or false
  end
  return langs[lang] and lang or nil
end

--- Ensures the hl groups are always set, even after a colorscheme change.
---@param groups table<string, string|vim.api.keyset.highlight>
---@param opts? { prefix?:string, default?:boolean }
function M.set_hl(groups, opts)
  opts = opts or {}
  for hl_group, hl in pairs(groups) do
    hl_group = opts.prefix and opts.prefix .. hl_group or hl_group
    hl = type(hl) == "string" and { link = hl } or hl --[[@as vim.api.keyset.highlight]]
    hl.default = opts.default
    hl_groups[hl_group] = hl
    vim.api.nvim_set_hl(0, hl_group, hl)
  end
end

---@param group string|string[] hl group to get color from
---@param prop? string property to get. Defaults to "fg"
function M.color(group, prop)
  prop = prop or "fg"
  group = type(group) == "table" and group or { group }
  ---@cast group string[]
  for _, g in ipairs(group) do
    local hl = vim.api.nvim_get_hl(0, { name = g, link = false })
    if hl[prop] then
      return string.format("#%06x", hl[prop])
    end
  end
end

--- Set window-local options.
function M.wo(win, wo)
  for k, v in pairs(wo or {}) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = win })
  end
end

--- Set buffer-local options.
function M.bo(buf, bo)
  for k, v in pairs(bo or {}) do
    vim.api.nvim_set_option_value(k, v, { buf = buf })
  end
end

local transparent ---@type boolean?
--- Check if the colorscheme is transparent.
function M.is_transparent()
  if transparent == nil then
    transparent = M.color("Normal", "bg") == nil
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ui_util_transparent", { clear = true }),
      callback = function()
        transparent = nil
      end,
    })
  end
  return transparent
end

--- Redraw the range of lines in the window.
---@param win number
---@param from number -- 1-indexed, inclusive
---@param to number -- 1-indexed, inclusive
function M.redraw_range(win, from, to)
  vim.api.nvim__redraw({ win = win, range = { math.floor(from - 1), math.floor(to) }, valid = true, flush = false })
end

---@param str string
function M.keycode(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local key_cache = {} ---@type table<string, string>

---@param key string
function M.normkey(key)
  if key_cache[key] then
    return key_cache[key]
  end
  local function norm(v)
    local l = v:lower()
    if l == "leader" then
      return M.normkey("<leader>")
    elseif l == "localleader" then
      return M.normkey("<localleader>")
    end
    return vim.fn.keytrans(M.keycode(("<%s>"):format(v)))
  end
  local orig = key
  key = key:gsub("<lt>", "<")
  local lower = key:lower()
  if lower == "<leader>" then
    key = vim.g.mapleader
    key = vim.fn.keytrans((not key or key == "") and "\\" or key)
  elseif lower == "<localleader>" then
    key = vim.g.maplocalleader
    key = vim.fn.keytrans((not key or key == "") and "\\" or key)
  else
    local extracted = {} ---@type string[]
    local function extract(v)
      v = v:sub(2, -2)
      if v:sub(2, 2) == "-" and v:sub(1, 1):find("[aAmMcCsS]") then
        local m = v:sub(1, 1):upper()
        m = m == "A" and "M" or m
        local k = v:sub(3)
        if #k > 1 then
          return norm(v)
        end
        if m == "C" then
          k = k:upper()
        elseif m == "S" then
          return k:upper()
        end
        return ("<%s-%s>"):format(m, k)
      end
      return norm(v)
    end
    local placeholder = "_#_"
    key = key:gsub("(%b<>)", function(v)
      table.insert(extracted, extract(v))
      return placeholder
    end)
    key = vim.fn.keytrans(key):gsub("<lt>", "<")
    local i = 0
    key = key:gsub(placeholder, function()
      i = i + 1
      return extracted[i] or ""
    end)
  end
  key_cache[orig] = key
  key_cache[key] = key
  return key
end

---@param msg string
---@param level? integer
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "ui.nvim" })
end

return M
