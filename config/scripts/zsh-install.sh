#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail


echo 'autoload -U colors && colors'
echo 'setopt autocd'
echo ''

echo '# Include hidden files in autocomplete:'
echo '_comp_options+=(globdots)'
echo ''

echo 'bindkey "^[[1;3C" forward-word'
echo 'bindkey "^[[1;3D" backward-word'
echo ''
echo '# History'
echo 'export HISTFILE=$ZDOTDIR/history'
echo '[[ -f "$HISTFILE" ]] || touch $HISTFILE'
echo 'export HISTCONTROL=ignoredups:erasedups'
echo 'export HISTSIZE=9999'
echo 'export SAVEHIST=9999'
echo 'setopt appendhistory'
echo ''

echo '[ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"'
echo ''

echo '[ -f /usr/bin/starship ] && eval "$(starship init zsh)"'
echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh'

# fsh
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting /usr/share/fsh

echo 'source /usr/share/fsh/fast-syntax-highlighting.plugin.zsh' >> /etc/zshrc
