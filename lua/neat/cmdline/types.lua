---@meta
-- Types the cmdline code (adapted from noice.nvim) uses but whose noice
-- definitions were not carried over. Never required at runtime.

--- The UI event a message came from.
---@alias NoiceEvent "cmdline"|"msg_show"|string

--- A message kind (`:h ui-messages`), or a cmdline format name.
---@alias NoiceKind string

---@alias NotifyLevel integer|string

--- View options for the nui backends (popup or split): nui's own options plus noice's.
--- relative, position, size and border take the many shapes nui accepts
--- (a string, a number, a table), so they are `any` here.
---@class NoiceNuiOptions: NoiceViewBaseOptions
---@field type? "popup"|"split"
---@field relative? any
---@field position? any
---@field size? any
---@field border? any
---@field min_size? number
---@field max_size? number
---@field win_options? table<string, any>
---@field zindex? integer
---@field enter? boolean
---@field focusable? boolean
---@field anchor? string
---@field scrollbar? boolean
---@field [string] any

--- NoiceNuiOptions after neat.cmdline.util.nui.normalize().
---@class _.NoiceNuiOptions: NoiceNuiOptions

---@class NuiPopupOptions: NoiceNuiOptions
---@class NuiSplitOptions: NoiceNuiOptions
---@class _.NuiPopupOptions: _.NoiceNuiOptions
---@class _.NuiSplitOptions: _.NoiceNuiOptions

---@alias _.NuiBorderStyle string|string[]

---@class _.NuiBorderPadding
---@field top integer
---@field right integer
---@field bottom integer
---@field left integer

---@class _.NuiBorder
---@field style? _.NuiBorderStyle
---@field padding? _.NuiBorderPadding|integer[]
---@field text? table
---@field [string] any

---@alias NuiBorder _.NuiBorder

--- noice's notify view options (unused by neat; kept so NoiceViewOptions resolves).
---@class NoiceNotifyOptions: NoiceViewBaseOptions
---@field type "notify"
