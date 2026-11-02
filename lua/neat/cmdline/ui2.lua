-- cmdline.nvim: coexistence with Neovim's experimental ui2 (vim._core.ui2).
--
-- When ui2 and cmdline.nvim are both attached, every cmdline event is drawn
-- twice: once in the centred popup and once in ui2's bottom "cmd" window.
-- This module keeps ui2's bottom line empty while the popup is open, and
-- every other ui2 feature (messages, :messages pager, showmode, showcmd,
-- ruler, dialogs) keeps working.
--
-- ui2 looks up handlers with `M.cmd[event]`, and its message module reads
-- cmdline state from the same table (`ui.cmd.level`, `ui.cmd.prompt`, ...).
-- We swap `ui2.cmd` for a proxy:
-- - `cmdline_show` still runs, but with empty content, so ui2 tracks the
--   cmdline level and prompt (it hides showcmd/ruler and routes messages to
--   its dialog window while a prompt is open) without drawing the text.
--   With `confirm.style = "ui2"`, confirm() and `:s///c` prompts are the
--   exception: ui2 draws them in full;
-- - with 'cmdheight' 0, `cmdline_show` only records that state: ui2 would
--   unhide its window and raise 'cmdheight' to 1 for an empty line, pushing
--   the statusline up a row on every `:`;
-- - `cmdline_pos` and `cmdline_special_char` are dropped (the cursor stays
--   in ui2's window for confirm(), which only waits for a key);
-- - `cmdline_hide` then hands ui2 a shown window, so ui2 hides it as usual;
-- - everything else, multi-line `cmdline_block_*` included, goes to ui2
--   unchanged.
-- This relies on a private, experimental Neovim module; if it changes shape,
-- we do nothing.

local M = {}

local MARK = "__cmdline_nvim_proxy"

---@type table<string, true>
local DROPPED = {
  cmdline_pos = true,
  cmdline_special_char = true,
}

---@return table?
local function get_ui2()
  return package.loaded["vim._core.ui2"]
end

local function patch()
  local ui2 = get_ui2()
  if type(ui2) ~= "table" or type(ui2.cmd) ~= "table" then
    return false
  end
  local mt = getmetatable(ui2.cmd)
  if mt and mt[MARK] then
    return true
  end
  local real = ui2.cmd
  if type(real.cmdline_show) ~= "function" then
    return false
  end
  local function cmdline_show(content, pos, firstc, prompt, indent, level, hl_id)
    if require("neat.cmdline.ui.cmdline").is_confirm(prompt) and not require("neat.cmdline.confirm").enabled() then
      return real.cmdline_show(content, pos, firstc, prompt, indent, level, hl_id)
    end
    -- ui2 still has to move an expanded message out of the way (cmd_on_key)
    -- and lay out multi-line blocks (srow > 0), so those keep the real call.
    local expanded = type(ui2.msg) == "table" and ui2.msg.cmd_on_key
    if ui2.cmdheight == 0 and not expanded and (real.srow or 0) == 0 then
      real.level, real.indent = level, indent
    else
      real.cmdline_show({}, 0, "", "", 0, level, 0)
    end
    real.prompt = prompt ~= nil and #prompt > 0
  end
  local function cmdline_hide(level, abort)
    local win = ui2.wins and ui2.wins.cmd
    -- Same test ui2 uses to skip hiding while a nested cmdline is still open.
    local nested = (real.srow or 0) > 0 or level > (vim.fn.getcmdwintype() == "" and 1 or 2)
    if
      ui2.cmdheight == 0
      and not nested
      and type(win) == "number"
      and vim.api.nvim_win_is_valid(win)
      and vim.api.nvim_win_get_config(win).hide
    then
      -- ui2 hides its window by flipping `hide`. If cmdline_show skipped it,
      -- the window is already hidden and ui2 would resize it to 0 rows
      -- instead, so hand it a shown window to hide.
      pcall(vim.api.nvim_win_set_config, win, { hide = false })
    end
    return real.cmdline_hide(level, abort)
  end
  ui2.cmd = setmetatable({}, {
    [MARK] = real,
    __index = function(_, key)
      if key == "cmdline_show" then
        return cmdline_show
      elseif key == "cmdline_hide" then
        return cmdline_hide
      elseif DROPPED[key] then
        return nil
      end
      return real[key]
    end,
    __newindex = real,
  })
  -- hide anything ui2 may have drawn in its cmdline window
  if real.level and real.level > 0 and type(real.cmdline_hide) == "function" then
    pcall(real.cmdline_hide, real.level, true)
  end
  return true
end

---@param opts? {disable_cmdline?: boolean}
function M.setup(opts)
  opts = opts or {}
  if opts.disable_cmdline == false then
    return
  end
  patch()
  -- ui2 may be enabled (or re-enabled) later, e.g. on UIEnter.
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("neat.cmdline.ui2", { clear = true }),
    callback = function()
      vim.schedule(patch)
    end,
  })
end

--- Whether ui2's cmdline handlers are wrapped right now.
---@return boolean
function M.is_patched()
  local ui2 = get_ui2()
  local mt = type(ui2) == "table" and type(ui2.cmd) == "table" and getmetatable(ui2.cmd)
  return mt and mt[MARK] ~= nil or false
end

function M.restore()
  pcall(vim.api.nvim_del_augroup_by_name, "neat.cmdline.ui2")
  local ui2 = get_ui2()
  if type(ui2) == "table" and type(ui2.cmd) == "table" then
    local mt = getmetatable(ui2.cmd)
    if mt and mt[MARK] then
      ui2.cmd = mt[MARK]
    end
  end
end

return M
