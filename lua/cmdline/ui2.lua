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
--   confirm() prompts are the exception: ui2 draws them in full;
-- - `cmdline_pos` and `cmdline_special_char` are dropped (the cursor stays
--   in ui2's window for confirm(), which only waits for a key);
-- - everything else, `cmdline_hide` and multi-line `cmdline_block_*`
--   included, goes to ui2 unchanged.
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
    if require("cmdline.ui.cmdline").is_confirm(prompt) then
      return real.cmdline_show(content, pos, firstc, prompt, indent, level, hl_id)
    end
    real.cmdline_show({}, 0, "", "", 0, level, 0)
    real.prompt = prompt ~= nil and #prompt > 0
  end
  ui2.cmd = setmetatable({}, {
    [MARK] = real,
    __index = function(_, key)
      if key == "cmdline_show" then
        return cmdline_show
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
    group = vim.api.nvim_create_augroup("cmdline.ui2", { clear = true }),
    callback = function()
      vim.schedule(patch)
    end,
  })
end

function M.restore()
  pcall(vim.api.nvim_del_augroup_by_name, "cmdline.ui2")
  local ui2 = get_ui2()
  if type(ui2) == "table" and type(ui2.cmd) == "table" then
    local mt = getmetatable(ui2.cmd)
    if mt and mt[MARK] then
      ui2.cmd = mt[MARK]
    end
  end
end

return M
