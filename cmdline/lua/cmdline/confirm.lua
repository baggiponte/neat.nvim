-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: noice's `confirm` view and formatter, rewritten as a standalone
-- float. The question comes from ui2's `msg_show` "confirm" event (or from the
-- prompt itself for `:s///c`) and the buttons from the cmdline prompt. Adds a
-- "toast" placement in the top-right corner.

local M = {}

---@class CmdlineConfirmOptions
---@field style "box"|"toast"|"ui2" box: centred near the top (noice); toast: top-right corner; ui2: leave it to ui2
---@field title string

---@type CmdlineConfirmOptions
M.opts = {
  style = "box",
  title = " Confirm ",
}

local ns = vim.api.nvim_create_namespace("cmdline.confirm")
local MARK = "__cmdline_nvim_msg_show"

---@type string?
M._question = nil
---@type string?
M._prompt = nil
---@type integer?
M._buf = nil
---@type integer?
M._win = nil

function M.enabled()
  return M.opts.style ~= "ui2"
end

-- Split a confirm prompt into its question and buttons.
-- "(Y)es, [N]o, (C)ancel: " -> nil, { "(Y)es", "[N]o", "(C)ancel" }
-- "replace with x? (y)es/(n)o/..." -> "replace with x?", { "(y)es", "(n)o", ... }
---@param prompt string
---@return string?, string[]
function M.parse(prompt)
  prompt = prompt:gsub("%s*:%s*$", "")
  local question, choices = prompt:match("^(.-%?)%s+([%(%[].*)$")
  choices = choices or prompt
  local sep = choices:find(", ", 1, true) and ", " or "/"
  return question, vim.split(choices, sep, { plain = true, trimempty = true })
end

---@param prompt string
function M.show(prompt)
  M._prompt = prompt
  local question, buttons = M.parse(prompt)
  question = M._question or question or ""

  local lines = vim.split(question, "\n", { plain = true })
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    lines[#lines] = nil
  end

  -- buttons on one line, each padded and highlighted; the default one is [x]
  local row_text, marks = "", {}
  for i, button in ipairs(buttons) do
    local text = " " .. button .. " "
    local from = #row_text
    row_text = row_text .. text .. (i < #buttons and " " or "")
    marks[#marks + 1] = {
      from,
      from + #text,
      button:find("%[") and "NoiceFormatConfirmDefault" or "NoiceFormatConfirm",
    }
  end

  local width = vim.api.nvim_strwidth(row_text)
  for _, l in ipairs(lines) do
    width = math.max(width, vim.api.nvim_strwidth(l))
  end
  width = math.min(width, vim.o.columns - 6)

  local pad = math.max(math.floor((width - vim.api.nvim_strwidth(row_text)) / 2), 0)
  local content = vim.deepcopy(lines)
  if #content > 0 then
    content[#content + 1] = ""
  end
  content[#content + 1] = (" "):rep(pad) .. row_text

  if not (M._buf and vim.api.nvim_buf_is_valid(M._buf)) then
    M._buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M._buf].filetype = "noice"
  end
  vim.api.nvim_buf_set_lines(M._buf, 0, -1, false, content)
  vim.api.nvim_buf_clear_namespace(M._buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(M._buf, ns, #content - 1, pad + m[1], {
      end_col = pad + m[2],
      hl_group = m[3],
    })
  end

  local toast = M.opts.style == "toast"
  local cfg = {
    relative = "editor",
    width = width + 2,
    height = #content,
    row = toast and 1 or 2,
    col = toast and (vim.o.columns - 1) or math.floor((vim.o.columns - width - 4) / 2),
    anchor = toast and "NE" or "NW",
    style = "minimal",
    border = "rounded",
    title = M.opts.title,
    title_pos = "center",
    focusable = false,
    zindex = 210,
    noautocmd = true,
  }
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    cfg.noautocmd = nil
    vim.api.nvim_win_set_config(M._win, cfg)
  else
    M._win = vim.api.nvim_open_win(M._buf, false, cfg)
    vim.wo[M._win].winhighlight = "Normal:NoiceConfirm,FloatBorder:NoiceConfirmBorder"
    vim.wo[M._win].wrap = true
  end
  -- center the question lines too
  vim.api.nvim_win_call(M._win, function()
    vim.cmd(("silent! 1,%dcenter %d"):format(math.max(#lines, 1), width + 2))
  end)
  vim.api.nvim__redraw({ flush = true, win = M._win })
end

function M.hide()
  M._question, M._prompt = nil, nil
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    vim.api.nvim_win_close(M._win, true)
  end
  M._win = nil
end

function M.is_visible()
  return M._win ~= nil and vim.api.nvim_win_is_valid(M._win)
end

---@return table?
local function get_ui2()
  local ui2 = package.loaded["vim._core.ui2"]
  if type(ui2) == "table" and type(ui2.msg) == "table" then
    return ui2
  end
end

-- Keep ui2 from drawing the confirm question; we show it in our float.
local function patch()
  local ui2 = get_ui2()
  if not ui2 or type(ui2.msg.msg_show) ~= "function" then
    return false
  end
  if ui2.msg[MARK] then
    return true
  end
  local msg_show = ui2.msg.msg_show
  ui2.msg[MARK] = msg_show
  ui2.msg.msg_show = function(kind, content, ...)
    if M.enabled() and kind == "confirm" then
      local text = {}
      for _, chunk in ipairs(content or {}) do
        text[#text + 1] = chunk[2]
      end
      M._question = table.concat(text)
      -- ui2 may get the question after the prompt (msg_show is scheduled)
      if M.is_visible() and M._prompt then
        M.show(M._prompt)
      end
      return
    end
    return msg_show(kind, content, ...)
  end
  return true
end

---@param opts? CmdlineConfirmOptions
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  if not M.enabled() then
    return
  end
  patch()
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("cmdline.confirm", { clear = true }),
    callback = function()
      vim.schedule(patch)
    end,
  })
end

function M.restore()
  M.hide()
  pcall(vim.api.nvim_del_augroup_by_name, "cmdline.confirm")
  local ui2 = get_ui2()
  if ui2 and ui2.msg[MARK] then
    ui2.msg.msg_show = ui2.msg[MARK]
    ui2.msg[MARK] = nil
  end
end

return M
