# Messages pager and confirm() prompts. Run through ./record.sh <name> dialogs.
Set Shell zsh
Set FontFamily "Hack Nerd Font Mono"
Set FontSize 16
Set Width 1280
Set Height 760
Set Padding 16
Set TypingSpeed 40ms
Set Theme { "name": "GruvboxMaterialTransparent", "black": "#1d1f21", "red": "#ea6962", "green": "#a9b665", "yellow": "#d8a657", "blue": "#7daea3", "magenta": "#d3869b", "cyan": "#89b482", "white": "#d4be98", "brightBlack": "#928374", "brightRed": "#ea6962", "brightGreen": "#a9b665", "brightYellow": "#d8a657", "brightBlue": "#7daea3", "brightMagenta": "#d3869b", "brightCyan": "#89b482", "brightWhite": "#ddc7a1", "background": "#1d1f21", "foreground": "#d4be98", "selection": "#3c3836", "cursor": "#d4be98" }

Hide
Type "cd ~/dev/projs/cmdline.nvim/demo && clear"
Enter
Type "timeout 120 nvim -n -i NONE sample.lua"
Enter
Sleep 5s
Show

# a few messages, then :messages
Type ":echomsg 'first message'"
Enter
Sleep 400ms
Type ":echomsg 'second message'"
Enter
Sleep 400ms
Type ":call NoSuchFunction()"
Enter
Sleep 800ms
Type ":messages"
Enter
Sleep 1500ms
Screenshot frames/d1-messages.png
Sleep 600ms
Type "q"
Sleep 800ms

# confirm()
Type `:call confirm("Save changes?", "&Yes\n&No\n&Cancel", 2)`
Enter
Sleep 1500ms
Screenshot frames/d2-confirm.png
Sleep 600ms
Type "y"
Sleep 800ms

# :s///c
Type ":%s/total/sum/gc"
Enter
Sleep 1500ms
Screenshot frames/d3-substitute.png
Sleep 600ms
Type "q"
Sleep 800ms

Hide
Type ":qa!"
Enter
Sleep 500ms
