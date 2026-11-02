# statusline.nvim demo. Run through ./record.sh, which adds Output and NVIM_APPNAME
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
Type "cd @FIXTURE@ && clear"
Enter
Type "timeout 180 nvim -n -i NONE sample.lua"
Enter
Show

# lua_ls attaches, gitsigns counts the diff, diagnostics arrive
Sleep 1s
Screenshot frames/01-open.png
Sleep 5s
Type "16G"
Sleep 800ms
Screenshot frames/02-lsp-diagnostics.png

# mode switches
Type "i"
Sleep 800ms
Screenshot frames/03-insert.png
Escape
Type "v"
Sleep 800ms
Screenshot frames/04-visual.png
Escape
Type "V"
Sleep 800ms
Screenshot frames/05-visual-line.png
Escape
Type "R"
Sleep 800ms
Screenshot frames/06-replace.png
Escape
Type ":"
Sleep 800ms
Screenshot frames/07-command.png
Escape
Sleep 400ms

# terminal mode; `exit` closes the buffer and returns to sample.lua
Type ":terminal"
Enter
Sleep 1500ms
Type "i"
Sleep 1s
Screenshot frames/08-terminal.png
Type "exit"
Enter
Sleep 1500ms

# a split: the inactive window uses the inactive layout
Type ":vsplit other.lua"
Enter
Sleep 1500ms
Screenshot frames/09-split.png
Type ":only"
Enter

# extensions
Type ":Neotree show"
Enter
Sleep 2s
Ctrl+w
Type "h"
Sleep 800ms
Screenshot frames/10-neo-tree.png
Type ":Neotree close"
Enter
Sleep 600ms
Type ":buffer sample.lua"
Enter
Type ":vimgrep /M\./ %"
Enter
Type ":copen"
Enter
Sleep 1s
Screenshot frames/11-quickfix.png
Type ":cclose"
Enter
Type ":Oil"
Enter
Sleep 1500ms
Screenshot frames/12-oil.png
Type ":Man ls"
Enter
Sleep 2500ms
Screenshot frames/13-man.png
Sleep 500ms

Hide
Type ":qa!"
Enter
Sleep 500ms
