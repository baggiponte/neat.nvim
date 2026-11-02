# confirm() before (style = "box", top centre) and after (style = "center").
# Run from the repo root with nui.nvim cloned into deps/nui.nvim:
#   CONFIRM_STYLE=box vhs dev/confirm-demo/confirm.tape -o dev/confirm-demo/out/box.gif
#   CONFIRM_STYLE=center vhs dev/confirm-demo/confirm.tape -o dev/confirm-demo/out/center.gif
Set Shell bash
Set FontFamily "Hack Nerd Font Mono"
Set FontSize 16
Set Width 1280
Set Height 760
Set Padding 16
Set TypingSpeed 40ms
Set Theme { "name": "GruvboxMaterialTransparent", "black": "#1d1f21", "red": "#ea6962", "green": "#a9b665", "yellow": "#d8a657", "blue": "#7daea3", "magenta": "#d3869b", "cyan": "#89b482", "white": "#d4be98", "brightBlack": "#928374", "brightRed": "#ea6962", "brightGreen": "#a9b665", "brightYellow": "#d8a657", "brightBlue": "#7daea3", "brightMagenta": "#d3869b", "brightCyan": "#89b482", "brightWhite": "#ddc7a1", "background": "#1d1f21", "foreground": "#d4be98", "selection": "#3c3836", "cursor": "#d4be98" }

Hide
Type "clear && nvim --clean -n -i NONE -u dev/confirm-demo/init.lua lua/neat/cmdline/confirm.lua"
Enter
Sleep 3s
Show

Sleep 500ms
Type `:call confirm("Save changes?", "&Yes\n&No\n&Cancel", 2)`
Enter
Sleep 2500ms
Type "n"
Sleep 1s

Hide
Type ":qa!"
Enter
