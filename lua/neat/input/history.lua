-- Adapted from snacks.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Source: lua/snacks/picker/util/history.lua + lua/snacks/picker/util/kv.lua
-- at folke/snacks.nvim v2.22.0 (5eac729fa290248acfe10916d92a5ed5e5c0f9ed).
-- Changes: merged the persistent key/value store and the history cursor into one module;
-- history file moved from `stdpath("data")/snacks/` to `stdpath("data")/ui/`.

local uv = vim.uv

--- A table persisted to `path` with string.buffer, trimmed to `max_size` entries on save.
---@class neat.input.KeyValue
---@field data table<any, any>
---@field path string
---@field max_size integer
---@field cmp fun(a: {key: any, value: any}, b: {key: any, value: any}): boolean sort order; the first `max_size` are kept
---@field loaded_time integer os.time() when the file was read
local KV = {}
KV.__index = KV

---@param path string
---@param opts? {max_size?: integer, cmp?: fun(a: {key: any, value: any}, b: {key: any, value: any}): boolean}
---@return neat.input.KeyValue
function KV.new(path, opts)
  local self = setmetatable({}, KV) --[[@as neat.input.KeyValue]]
  self.data = {}
  self.path = path
  self.max_size = opts and opts.max_size or 10000
  self.cmp = opts and opts.cmp or function(a, b)
    return a.value > b.value
  end
  self.loaded_time = os.time()
  local fd = io.open(path, "rb")
  if fd then
    local data = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(require("string.buffer").decode, data)
    self.data = ok and decoded or {}
  end
  return self
end

---@param key any
---@param value any
function KV:set(key, value)
  self.data[key] = value
end

---@param key any
---@return any
function KV:get(key)
  return self.data[key]
end

--- Write the data, unless another Neovim saved the file since we read it.
function KV:close()
  vim.fn.mkdir(vim.fn.fnamemodify(self.path, ":h"), "p")
  local stat = uv.fs_stat(self.path)
  -- check if the file was modified since we loaded it
  if self.loaded_time > 0 and stat and stat.mtime.sec > self.loaded_time then
    return
  end
  local entries = {}
  for k, v in pairs(self.data) do
    table.insert(entries, { key = k, value = v })
  end
  table.sort(entries, self.cmp)
  self.data = {}
  for i = 1, math.min(#entries, self.max_size) do
    local entry = entries[i]
    self.data[entry.key] = entry.value
  end
  local fd = io.open(self.path, "w+b")
  if not fd then
    return
  end
  fd:write(require("string.buffer").encode(self.data))
  fd:close()
end

--- A cursor over one history list (`:h neat-input`).
---@class neat.input.History
---@field path string
---@field kv neat.input.KeyValue
---@field idx integer where the next entry goes (one past the last)
---@field cursor integer the entry shown, `idx` when none
local M = {}
M.__index = M

---@type table<string, neat.input.KeyValue>
M.stores = {}

-- Save the history on exit
vim.api.nvim_create_autocmd("ExitPre", {
  group = vim.api.nvim_create_augroup("ui_history", { clear = true }),
  callback = function()
    for n, kv in pairs(M.stores) do
      kv:close()
      M.stores[n] = nil
    end
  end,
})

---@param name string
---@param opts? {filter?: fun(value: string): boolean}
---@return neat.input.History
function M.new(name, opts)
  opts = opts or {}
  local self = setmetatable({}, M) --[[@as neat.input.History]]
  self.path = vim.fn.stdpath("data") .. "/ui/" .. name .. ".history"
  if not M.stores[name] then
    M.stores[name] = KV.new(self.path, {
      max_size = 1000,
      cmp = function(a, b)
        return a.key > b.key
      end,
    })
  end
  self.kv = M.stores[name]
  -- re-index the data
  self.kv.data = vim.tbl_values(self.kv.data)
  if opts.filter then
    self.kv.data = vim.tbl_filter(opts.filter, self.kv.data)
  end
  self.idx = #self.kv.data + 1
  self.cursor = self.idx
  return self
end

---@return boolean
function M:is_current()
  return self.cursor == self.idx
end

---@param value string
function M:record(value)
  self.kv:set(self.idx, value)
end

---@return string?
function M:next()
  self.cursor = math.min(self.cursor + 1, self.idx)
  return self:get()
end

---@return string?
function M:prev()
  self.cursor = math.max(self.cursor - 1, 1)
  return self:get()
end

---@return string?
function M:get()
  return self.kv:get(self.cursor)
end

return M
