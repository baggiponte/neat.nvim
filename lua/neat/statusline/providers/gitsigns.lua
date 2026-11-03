-- The `gitsigns` git provider: lewis6991/gitsigns.nvim. It only reads the
-- buffer variables gitsigns sets (`b:gitsigns_head`, `b:gitsigns_status_dict`),
-- so it never loads gitsigns; without it the branch comes from .git/HEAD.

---@type neat.statusline.GitProvider
return {
  status = function(buf)
    local b = vim.b[buf]
    local st = b.gitsigns_status_dict or {} ---@type {added?: integer, changed?: integer, removed?: integer}
    return { head = b.gitsigns_head, added = st.added, changed = st.changed, removed = st.removed }
  end,
  events = { { event = 'User', pattern = { 'GitSignsUpdate', 'GitSignsChanged' } } },
}
