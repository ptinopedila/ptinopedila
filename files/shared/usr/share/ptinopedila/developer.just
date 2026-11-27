# Choose optional developer tools to install on the current image.
[group('Setup')]
devmode:
    @/usr/libexec/ptinopedila/developer-tools

# Open the developer tool picker using the older command name.
[private]
toggle-devmode: devmode
