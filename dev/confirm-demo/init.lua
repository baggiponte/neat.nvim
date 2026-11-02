-- Minimal config for confirm.tape: neat's cmdline on ui2, with the confirm
-- style taken from $CONFIRM_STYLE so one tape records both placements.
local root = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h"))
vim.opt.rtp:prepend(root .. "/deps/nui.nvim")
vim.opt.rtp:prepend(root)
vim.o.termguicolors = true
vim.o.number = true
vim.cmd.colorscheme("habamax")
require("vim._core.ui2").enable({})
require("neat").setup({
  statusline = { enabled = true },
  cmdline = { enabled = true, confirm = { style = vim.env.CONFIRM_STYLE or "center" } },
})
