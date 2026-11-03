-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: noice's `confirm` view and formatter, rewritten as a standalone
-- float. The question comes from ui2's `msg_show` "confirm" event, handed over
-- by neat.cmdline.messages (or from the prompt itself for `:s///c`), and the
-- buttons from the cmdline prompt. Adds "center" (middle of the editor) and
-- "toast" (top-right corner) placements.

local M = {}

---@class CmdlineConfirmOptions
---@field style "center"|"box"|"toast"|"ui2" center: middle of the editor; box: centred near the top (noice); toast: top-right corner; ui2: leave it to ui2
---@field title string

---@type CmdlineConfirmOptions
M.opts = {
  style = "center",
  title = " Confirm ",
}

local ns = vim.api.nvim_create_namespace("neat.cmdline.confirm")

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
  local row = toast and 1 or 2
  if M.opts.style == "center" then
    -- the cmdline and statusline sit below the editor area, so centre within
    -- the lines that are left; the +2 is the border
    local area = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
    row = math.max(math.floor((area - #content - 2) / 2), 0)
  end
  local cfg = {
    relative = "editor",
    width = width + 2,
    height = #content,
    row = row,
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

---@type "confirm"|"other"|nil kind of the prompt the cmdline shows right now
M._prompt_kind = nil
---@type fun()?
M._pending = nil

-- Since Neovim 0.12 the text before every prompt that waits for a key or a
-- number arrives as a "confirm" message: confirm() and `:s///c` questions,
-- but also the `z=` suggestions and inputlist() items. Only choice prompts
-- ("(Y)es, [N]o") open our float; the rest go back to ui2. The message may
-- come before or after its prompt, so hold it until we know which.

--- A "confirm" message from ui2 (neat.cmdline.messages calls this).
---@param content [integer, string, integer][]
---@param forward fun() hands the message to ui2
function M.on_message(content, forward)
  local text = require("neat.cmdline.messages").text(content)
  if M._prompt_kind == "other" then
    return M.forward(forward)
  end
  M._question = text
  if M._prompt_kind == "confirm" then
    -- the question came after the prompt (ui2 schedules some messages)
    if M.is_visible() and M._prompt then
      M.show(M._prompt)
    end
    return
  end
  M._pending = forward
end

--- Hand a message to ui2 while a prompt is open, so ui2 shows it in its
--- dialog window (which stays until the prompt is answered) rather than as a
--- message that times out.
---@param forward fun()
function M.forward(forward)
  local ui2 = package.loaded["vim._core.ui2"]
  local cmd = type(ui2) == "table" and type(ui2.cmd) == "table" and ui2.cmd or nil
  if cmd and not cmd.prompt then
    cmd.prompt = true
  end
  forward()
end

--- The cmdline opened a prompt (called for ui2's and neat's cmdline_show).
---@param prompt string
function M.on_prompt(prompt)
  local kind = require("neat.cmdline.ui.cmdline").is_confirm(prompt) and "confirm" or "other"
  if M._prompt_kind == kind then
    return
  end
  M._prompt_kind = kind
  local pending = M._pending
  M._pending = nil
  if kind == "other" then
    M._question = nil
    if pending then
      M.forward(pending)
    end
  end
end

--- The prompt closed.
function M.reset()
  M._prompt_kind, M._pending = nil, nil
  M.hide()
end

---@param opts? CmdlineConfirmOptions
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
end

function M.restore()
  M.reset()
end

return M
