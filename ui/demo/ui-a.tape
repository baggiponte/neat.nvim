# ui.nvim review demo. demo/record.sh renders this once per config, replacing nvim-ui-a and ui-a;
# everything else is identical across the baseline and the variants.
Output ui-a.gif
Output ui-a.mp4

Require nvim
Set Shell zsh
Set FontFamily "DejaVuSansM Nerd Font Mono"
Set FontSize 15
Set Width 1400
Set Height 820
Set Padding 12
Set Theme "GruvboxDark"
Set TypingSpeed 40ms

Hide
Type "cd ~/dev/projs/ui.nvim && clear" Enter
Show

# LSP attach: lua_ls reports workspace loading progress
Type "timeout 120 env NVIM_APPNAME=nvim-ui-a nvim demo/fixture.lua" Enter
Sleep 6s

# indent guides and the current scope while moving through nested blocks
Type "10G"
Sleep 800ms
Type "jjj"
Sleep 800ms
Type "kkkkkk"
Sleep 1s

# gra: code actions in the select dropdown, then cancel
Type ":call cursor(6, 9)" Enter
Sleep 500ms
Type "gra"
Sleep 2500ms
Escape
Sleep 300ms
Escape
Sleep 800ms

# grn: rename input, typed into and cancelled
Type ":call cursor(6, 9)" Enter
Sleep 300ms
Type "grn"
Sleep 1200ms
Type "_count"
Sleep 1200ms
Escape
Sleep 300ms
Escape
Sleep 800ms

# a WARN and an ERROR notification
Type ":lua vim.notify('Formatter took 2.1s', vim.log.levels.WARN)" Enter
Sleep 1500ms
Type ":lua vim.notify('Linter crashed: exit code 1', vim.log.levels.ERROR)" Enter
Sleep 2500ms

# notification history (snacks in the baseline, the active backend in the variants)
Type ":lua (rawget(_G, 'Snacks') and Snacks.notifier.show_history or require('ui.notify').history)()" Enter
Sleep 3s
Type "q"
Sleep 500ms
Escape
Sleep 300ms

Type ":qa!" Enter
Sleep 500ms
