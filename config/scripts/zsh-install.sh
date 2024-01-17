#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

echo 'mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' >> /etc/zprofile

echo 'autoload -U colors && colors' >> /etc/zshrc
echo 'setopt autocd' >> /etc/zshrc
echo '' >> /etc/zshrc

echo '# Include hidden files in autocomplete:' >> /etc/zshrc
echo '_comp_options+=(globdots)' >> /etc/zshrc
echo '' >> /etc/zshrc

echo 'bindkey "^[[1;3C" forward-word' >> /etc/zshrc
echo 'bindkey "^[[1;3D" backward-word' >> /etc/zshrc
echo '' >> /etc/zshrc
echo '# History' >> /etc/zshrc
echo 'export HISTFILE=$ZDOTDIR/history' >> /etc/zshrc
echo '[[ -f "$HISTFILE" ]] || touch $HISTFILE || export HISTFILE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh_history" && touch $HISTFILE' >> /etc/zshrc
echo 'export HISTCONTROL=ignoredups:erasedups' >> /etc/zshrc
echo 'export HISTSIZE=99999' >> /etc/zshrc
echo 'export SAVEHIST=99999' >> /etc/zshrc
echo 'setopt appendhistory' >> /etc/zshrc
echo '# Immediate append' >> /etc/zshrc
echo 'setopt INC_APPEND_HISTORY' >> /etc/zshrc
echo 'export HISTTIMEFORMAT="[%F %T] "' >> /etc/zshrc
echo '# Add timestamp to history' >> /etc/zshrc
echo 'setopt EXTENDED_HISTORY' >> /etc/zshrc
echo '' >> /etc/zshrc

echo '[ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"' >> /etc/zshrc
echo '' >> /etc/zshrc

echo '[ -f /usr/bin/starship ] && eval "$(starship init zsh)"' >> /etc/zshrc
echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> /etc/zshrc

# fsh
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting /usr/share/fsh

echo 'source /usr/share/fsh/fast-syntax-highlighting.plugin.zsh' >> /etc/zshrc

echo 'ZDOTDIR=$HOME/.config/zsh' > /etc/zshenv
