-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: module paths renamed from noice to cmdline; no longer shadows `require`.
--
-- `lazy("mod")` returns the module if it is loaded, else a proxy that requires
-- it on first use. The cmdline modules require each other in a cycle (config,
-- util, view, ...), and nui.nvim only needs to load once the popup opens.
-- Annotate the local with `---@module "mod"` so LuaLS knows its type.

---@param module string
---@return any
return function(module)
  local mod = nil

  local function load()
    if not mod then
      mod = require(module)
      package.loaded[module] = mod
    end
    return mod
  end
  return type(package.loaded[module]) == "table" and package.loaded[module]
    or setmetatable({}, {
      __index = function(_, key)
        return load()[key]
      end,
      __newindex = function(_, key, value)
        load()[key] = value
      end,
      __call = function(_, ...)
        return load()(...)
      end,
    })
end
