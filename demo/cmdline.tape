# cmdline.nvim demo. Run through ./record.sh, which adds Output and NVIM_APPNAME
# so the same steps run against the baseline config and the review variant.
Set Shell zsh
Set FontFamily "Hack Nerd Font Mono"
Set FontSize 16
Set Width 1280
Set Height 760
Set Padding 16
Set TypingSpeed 60ms
Set Theme { "name": "GruvboxMaterialTransparent", "black": "#1d1f21", "red": "#ea6962", "green": "#a9b665", "yellow": "#d8a657", "blue": "#7daea3", "magenta": "#d3869b", "cyan": "#89b482", "white": "#d4be98", "brightBlack": "#928374", "brightRed": "#ea6962", "brightGreen": "#a9b665", "brightYellow": "#d8a657", "brightBlue": "#7daea3", "brightMagenta": "#d3869b", "brightCyan": "#89b482", "brightWhite": "#ddc7a1", "background": "#1d1f21", "foreground": "#d4be98", "selection": "#3c3836", "cursor": "#d4be98" }

Hide
Type "cd ~/dev/projs/cmdline.nvim/demo && clear"
Enter
Type "timeout 120 nvim -n -i NONE sample.lua"
Enter
Sleep 5s
Show

# : with completion
Type ":"
Sleep 700ms
Screenshot frames/01-colon.png
Sleep 600ms
Type "set nu"
Sleep 1s
Screenshot frames/02-completion.png
Sleep 600ms
Escape
Sleep 500ms

# :lua with syntax highlighting
Type ":lua vim.print(vim.fn.getcwd())"
Sleep 800ms
Screenshot frames/03-lua.png
Sleep 600ms
Enter
Sleep 1s
Screenshot frames/04-lua-result.png
Sleep 600ms

# / search
Type "/total"
Sleep 800ms
Screenshot frames/05-search.png
Sleep 600ms
Enter
Sleep 600ms

# ? search
Type "?greet"
Sleep 800ms
Screenshot frames/06-search-up.png
Sleep 600ms
Escape
Sleep 500ms

# :! filter
Type ":!ls"
Sleep 800ms
Screenshot frames/07-filter.png
Sleep 600ms
Enter
Sleep 1500ms
Screenshot frames/08-filter-output.png
Sleep 600ms
Enter
Sleep 600ms

# :echo
Type ":echo 'hello from the cmdline'"
Sleep 600ms
Enter
Sleep 800ms
Screenshot frames/09-echo.png
Sleep 600ms

# an error
Type ":call NoSuchFunction()"
Sleep 600ms
Enter
Sleep 1s
Screenshot frames/10-error.png
Sleep 600ms

# input() prompt
Type ":call input('Name: ')"
Enter
Sleep 800ms
Type "Luca"
Sleep 600ms
Screenshot frames/11-input.png
Sleep 600ms
Escape
Sleep 500ms

# :messages
Type ":messages"
Sleep 500ms
Enter
Sleep 1200ms
Screenshot frames/12-messages.png
Sleep 600ms
Type "q"
Sleep 500ms

# long command scrolls horizontally
Type ":echo 'a very long command line that keeps going so the popup has to grow wider than its minimum width'"
Sleep 800ms
Screenshot frames/13-long.png
Sleep 600ms
Escape
Sleep 600ms

Hide
Type ":qa!"
Enter
Sleep 500ms
