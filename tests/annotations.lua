-- Checks that every named function in lua/ and plugin/ documents its
-- parameters with `---@param` (or is typed as a whole with `---@type` or
-- `---@overload`). Functions written as table fields (`callback = function(args)`,
-- a backend's `select = function(...)`) are not checked: LuaLS types them
-- from the table's or the call's annotation. LuaLS checks that annotations
-- are right; this checks that they are there.
--
--   nvim --headless --clean -l tests/annotations.lua
--
-- Exits non-zero and lists the functions that are missing annotations.

---@param path string
---@return string[]
local function read_lines(path)
  local lines = {}
  for line in io.lines(path) do
    lines[#lines + 1] = line
  end
  return lines
end

--- The annotation block right above line `i` (contiguous `---` lines).
---@param lines string[]
---@param i integer
---@return string
local function doc_above(lines, i)
  local doc = {}
  local j = i - 1
  while j > 0 and lines[j]:match("^%s*%-%-%-") do
    table.insert(doc, 1, lines[j])
    j = j - 1
  end
  return table.concat(doc, "\n")
end

---@param params string
---@return string[]
local function param_names(params)
  local names = {}
  for name in params:gmatch("[%w_]+") do
    names[#names + 1] = name
  end
  return names
end

---@param path string
---@return string[] problems
local function check_file(path)
  local problems = {}
  local lines = read_lines(path)
  for i, line in ipairs(lines) do
    -- named functions: `function M.x(a)`, `local function x(a)`, `M.x = function(a)`, `local x = function(a)`
    local params = line:match("^%s*local%s+function%s+[%w_]+%s*%((.-)%)")
      or line:match("^%s*function%s+[%w_.:]+%s*%((.-)%)")
      or line:match("^%s*[%w_]+[.%[][%w_.%[%]\"']*%s*=%s*function%s*%((.-)%)")
      or line:match("^%s*local%s+[%w_]+%s*=%s*function%s*%((.-)%)")
    if params then
      local doc = doc_above(lines, i)
      local inline = line:match("%-%-%-@type") or line:match("%-%-%[%[@as")
      if not inline and not doc:find("@type", 1, true) and not doc:find("@overload", 1, true) then
        for _, name in ipairs(param_names(params)) do
          if name ~= "_" and name ~= "self" and not doc:find("@param%s+" .. name .. "[%s?]") then
            problems[#problems + 1] = ("%s:%d: `%s` has no ---@param"):format(path, i, name)
          end
        end
      end
    end
  end
  return problems
end

local problems = {} ---@type string[]
local files = vim.fs.find(function(name)
  return name:match("%.lua$") ~= nil
end, { path = "lua", limit = math.huge, type = "file" })
vim.list_extend(
  files,
  vim.fs.find(function(name)
    return name:match("%.lua$") ~= nil
  end, { path = "plugin", limit = math.huge, type = "file" })
)
table.sort(files)
for _, file in ipairs(files) do
  vim.list_extend(problems, check_file(file))
end
for _, p in ipairs(problems) do
  io.stdout:write(p .. "\n")
end
io.stdout:write(("%d function parameter(s) without ---@param\n"):format(#problems))
os.exit(#problems == 0 and 0 or 1)
