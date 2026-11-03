-- Where the statusline gets file icons and git status from. A provider is a
-- small adapter around a plugin (`:h neat-statusline-providers`); the ones
-- that ship with neat are listed here by name and required only when chosen.

--- File icons for the `fileicon` component.
---@class neat.statusline.IconProvider
--- Load the icon plugin and say whether it is there. Called once, on the tick
--- after the first draw that needs an icon: the statusline is drawn under
--- textlock, where a plugin manager's require hook may fail with E565.
---@field load fun(): boolean
--- Icon and highlight group for a file, or nil for none. Called while
--- drawing, only after load() returned true; must not load anything.
---@field get fun(name: string, filetype: string): (icon: string?, hl_group: string?)

--- A buffer's git status, as a git provider reports it.
---@class neat.statusline.GitStatus
---@field head? string branch name; nil or "" reads it from .git/HEAD
---@field added? integer
---@field changed? integer
---@field removed? integer

--- Branch and diff counts for the `branch` and `diff` components.
---@class neat.statusline.GitProvider
--- Status of a buffer, or nil when the provider knows nothing about it.
--- Called while drawing (results are cached until one of `events`); must not load anything.
---@field status fun(buf: integer): neat.statusline.GitStatus?
--- Autocmds after which cached statuses are stale. With `data.buffer` in the
--- event, only that buffer's status is dropped.
---@field events? {event: string|string[], pattern?: string|string[]}[]

---@alias neat.statusline.IconProviderName "devicons"
---@alias neat.statusline.GitProviderName "gitsigns"

---@class neat.statusline.Providers
---@field icons? neat.statusline.IconProviderName|neat.statusline.IconProvider|false false: no file icons
---@field git? neat.statusline.GitProviderName|neat.statusline.GitProvider|false false: branch from .git/HEAD, no diff

local M = {}

---@type table<neat.statusline.IconProviderName, string>
M.ICONS = { devicons = 'neat.statusline.providers.devicons' }
---@type table<neat.statusline.GitProviderName, string>
M.GIT = { gitsigns = 'neat.statusline.providers.gitsigns' }

---@param spec neat.statusline.IconProviderName|neat.statusline.IconProvider|false|nil
---@return neat.statusline.IconProvider?
function M.icons(spec)
  if type(spec) == 'string' then
    return require(M.ICONS[spec])
  end
  return spec or nil
end

---@param spec neat.statusline.GitProviderName|neat.statusline.GitProvider|false|nil
---@return neat.statusline.GitProvider?
function M.git(spec)
  if type(spec) == 'string' then
    return require(M.GIT[spec])
  end
  return spec or nil
end

--- vim.validate() checks for the `providers` option.
---@param providers neat.statusline.Providers
function M.validate(providers)
  vim.validate('providers', providers, 'table')
  vim.validate('providers.icons', providers.icons, function(v)
    return v == false
      or M.ICONS[v] ~= nil
      or (type(v) == 'table' and vim.is_callable(v.load) and vim.is_callable(v.get))
  end, false, '"devicons", false or a table with load() and get()')
  vim.validate('providers.git', providers.git, function(v)
    return v == false or M.GIT[v] ~= nil or (type(v) == 'table' and vim.is_callable(v.status))
  end, false, '"gitsigns", false or a table with status()')
end

return M
