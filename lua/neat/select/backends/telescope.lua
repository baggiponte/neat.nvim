-- Adapted from dressing.nvim (MIT) by Steven Arcangeli; modified.
-- Source: lua/dressing/select/telescope.lua at stevearc/dressing.nvim 2d7c2db2507fa3c4956142ee607431ddb2828639.
-- Changes: a neat.select.Backend; dropped the Neovim < 0.10 branch of the code-action display;
-- a code action from a client that has gone away shows without its client name.
--
-- The `telescope` select backend: a telescope.nvim dropdown, with dressing's
-- column layout for code actions. telescope.nvim must be installed; it is
-- required on the first vim.ui.select(), never at startup.

---@class neat.select.TelescopeEntry
---@field idx integer
---@field display string|fun(entry: neat.select.TelescopeEntry): string
---@field text string
---@field client_name string
---@field ordinal string
---@field value any

--- Change telescope's `picker` defaults for a vim.ui.select() kind.
---@type table<string, fun(opts: neat.select.Opts, picker: table, items: any[])>
local custom_kind = {
  --- `vim.lsp.buf.code_action()`: index, title and client name in columns.
  codeaction = function(opts, picker, items)
    local entry_display = require("telescope.pickers.entry_display")
    local finders = require("telescope.finders")
    local displayer ---@type fun(columns: table): string

    ---@param entry neat.select.TelescopeEntry
    ---@return string
    local function make_display(entry)
      return displayer({
        { entry.idx .. ":", "TelescopePromptPrefix" },
        entry.text,
        { entry.client_name, "Comment" },
      })
    end

    local entries = {} ---@type neat.select.TelescopeEntry[]
    local client_width, text_width, idx_width = 1, 1, 1
    for idx, item in ipairs(items) do
      local client = vim.lsp.get_client_by_id(item.ctx.client_id)
      local client_name = client and client.name or ""
      local text = opts.format_item(item)

      client_width = math.max(client_width, vim.api.nvim_strwidth(client_name))
      text_width = math.max(text_width, vim.api.nvim_strwidth(text))
      idx_width = math.max(idx_width, vim.api.nvim_strwidth(tostring(idx)))

      entries[#entries + 1] = {
        idx = idx,
        display = make_display,
        text = text,
        client_name = client_name,
        ordinal = idx .. " " .. text .. " " .. client_name,
        value = item,
      }
    end
    displayer = entry_display.create({
      separator = " ",
      items = {
        { width = idx_width + 1 },
        { width = text_width },
        { width = client_width },
      },
    })

    picker.finder = finders.new_table({
      results = entries,
      ---@param entry neat.select.TelescopeEntry
      entry_maker = function(entry)
        return entry
      end,
    })
  end,
}

---@param items any[]
---@param opts neat.select.Opts
---@param on_choice neat.select.OnChoice
---@param picker_opts? table telescope picker opts (`select.telescope`); the dropdown theme when nil
local function select(items, opts, on_choice, picker_opts)
  local themes = require("telescope.themes")
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  -- Closing telescope's windows is deferred (telescope.nvim#2336): call back
  -- once we are in the original window again.
  on_choice = vim.schedule_wrap(on_choice)

  local picker = {
    prompt_title = opts.prompt,
    previewer = false,
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        local formatted = opts.format_item(item)
        return { display = formatted, ordinal = formatted, value = item }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    ---@param prompt_bufnr integer
    ---@return boolean
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = state.get_selected_entry()
        local callback = on_choice
        -- closing calls on_choice(nil) below; this pick already answers
        on_choice = function() end
        actions.close(prompt_bufnr)
        if not selection then
          callback(nil, nil)
          return
        end
        for i, item in ipairs(items) do
          if item == selection.value then
            return callback(item, i)
          end
        end
        callback(selection.value, nil)
      end)

      actions.close:enhance({
        post = function()
          on_choice(nil, nil)
        end,
      })

      return true
    end,
  }

  if custom_kind[opts.kind] then
    custom_kind[opts.kind](opts, picker, items)
  end

  -- the caller of vim.ui.select() can pass telescope opts as `opts.telescope`
  pickers.new(opts.telescope or picker_opts or themes.get_dropdown(), picker):find()
end

---@type neat.select.Backend
return {
  available = function()
    return (pcall(require, "telescope"))
  end,
  select = select,
}
