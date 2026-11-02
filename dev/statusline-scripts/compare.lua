-- Dump the rendered statusline (text + resolved colours) for a fixed set of
-- scenarios, so lualine and statusline.nvim can be diffed.
-- Usage: CMP_FILE=<file> CMP_OUT=<out> NVIM_APPNAME=<cfg> nvim --headless -c 'luafile scripts/compare.lua'
local file, outpath = os.getenv('CMP_FILE'), os.getenv('CMP_OUT')
vim.o.columns, vim.o.lines = 160, 40
if os.getenv('CMP_NOTGC') then
  vim.o.termguicolors = false
end
vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy' })

local out = {}

local function color(group)
  local h = vim.api.nvim_get_hl(0, { name = group, link = false })
  local function hex(v)
    return v and string.format('#%06x', v) or '-'
  end
  return string.format('fg=%s bg=%s cterm=%s%s', hex(h.fg), hex(h.bg), h.ctermfg or '-', h.bold and ' bold' or '')
end

local function dump(label, win)
  win = win or vim.api.nvim_get_current_win()
  if package.loaded.lualine then
    require('lualine').refresh({ force = true, place = { 'statusline' } })
  end
  local str = vim.wo[win].statusline
  if str == '' then
    str = vim.go.statusline
  end
  local r = vim.api.nvim_eval_statusline(str, { winid = win, highlights = true, maxwidth = 160 })
  local lines = { '## ' .. label, 'text: [' .. r.str .. ']' }
  for i, h in ipairs(r.highlights) do
    local stop = r.highlights[i + 1] and r.highlights[i + 1].start or #r.str
    local seg = r.str:sub(h.start + 1, stop)
    if seg:match('%S') then
      local group = h.groups and h.groups[#h.groups] or h.group
      lines[#lines + 1] = string.format('  %-40s %s', '[' .. seg .. ']', color(group))
    end
  end
  out[#out + 1] = table.concat(lines, '\n')
end
_G.Dump = dump

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

vim.cmd.edit(file)
vim.wait(4000, function()
  return vim.b.gitsigns_status_dict ~= nil and vim.b.gitsigns_status_dict.added ~= nil
end)
vim.wait(1500) -- let lualine's own git diff job finish too
vim.cmd('normal! 5G')
dump('normal')

local ns = vim.api.nvim_create_namespace('compare')
vim.diagnostic.set(ns, 0, {
  { lnum = 0, col = 0, message = 'e', severity = vim.diagnostic.severity.ERROR },
  { lnum = 1, col = 0, message = 'w', severity = vim.diagnostic.severity.WARN },
  { lnum = 2, col = 0, message = 'w', severity = vim.diagnostic.severity.WARN },
  { lnum = 3, col = 0, message = 'h', severity = vim.diagnostic.severity.HINT },
})
vim.wait(200)
dump('diagnostics')

feed("i<Cmd>lua Dump('insert')<CR><Esc>")
feed("v<Cmd>lua Dump('visual')<CR><Esc>")
feed("V<Cmd>lua Dump('visual line')<CR><Esc>")
feed("R<Cmd>lua Dump('replace')<CR><Esc>")
feed(":<Cmd>lua Dump('command')<CR><Esc>")

vim.cmd('normal! G')
dump('bottom')

-- an in-process LSP server, so the lsp component has a client to show
vim.lsp.start({
  name = 'fake_ls',
  cmd = function()
    return {
      request = function(method, _, cb)
        if method == 'initialize' then
          cb(nil, { capabilities = {} })
        else
          cb(nil, nil)
        end
        return true, 1
      end,
      notify = function()
        return true
      end,
      is_closing = function()
        return false
      end,
      terminate = function() end,
    }
  end,
})
vim.wait(500, function()
  return #vim.lsp.get_clients({ bufnr = 0 }) > 0
end)
vim.wait(100)
dump('lsp attached')
feed("i<Cmd>lua Dump('insert + lsp')<CR><Esc>")

local filewin = vim.api.nvim_get_current_win()
vim.cmd('vsplit')
vim.cmd('enew')
dump('split: active [No Name]')
dump('split: inactive file', filewin)
vim.cmd('only')

vim.cmd('terminal')
vim.wait(300)
-- terminal mode only starts once we're back in the main loop
vim.cmd('startinsert')
vim.defer_fn(function()
  dump('terminal')
  vim.cmd('stopinsert')
  vim.defer_fn(function()
    rest()
  end, 100)
end, 300)
function _G.rest()
  dump('terminal-normal')
  vim.cmd('bwipeout!')

  vim.cmd.edit(file)
  vim.fn.setqflist({}, ' ', { title = 'compare qf', items = { { filename = file, lnum = 1, text = 'x' } } })
  vim.cmd('copen')
  dump('quickfix')
  vim.cmd('cclose')

  pcall(vim.cmd, 'Man ls')
  if vim.bo.filetype == 'man' then
    dump('man')
    vim.cmd('bwipeout!')
  end

  local ok = pcall(vim.cmd, 'Oil ' .. vim.fn.fnamemodify(file, ':h'))
  if ok then
    vim.wait(500, function()
      return vim.bo.filetype == 'oil'
    end)
    dump('oil')
  end

  vim.cmd.edit(file)
  ok = pcall(vim.cmd, 'Neotree show left')
  if ok then
    vim.wait(1000, function()
      return vim.bo[vim.api.nvim_win_get_buf(vim.fn.win_getid(1))].filetype == 'neo-tree'
    end)
    vim.cmd('wincmd h')
    dump('neo-tree')
    vim.cmd('Neotree close')
  end

  ok = pcall(vim.cmd, 'Lazy')
  if ok then
    vim.wait(500, function()
      return vim.bo.filetype == 'lazy'
    end)
    -- lazy is a float; the statusline that matters is the window behind it
    dump('lazy (window under float)', vim.fn.win_getid(1))
  end

  local fd = assert(io.open(outpath, 'w'))
  fd:write(table.concat(out, '\n\n') .. '\n')
  fd:close()
  vim.cmd('qa!')
end
