#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail


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
echo '[[ -f "$HISTFILE" ]] || touch $HISTFILE' >> /etc/zshrc
echo 'export HISTCONTROL=ignoredups:erasedups' >> /etc/zshrc
echo 'export HISTSIZE=9999' >> /etc/zshrc
echo 'export SAVEHIST=9999' >> /etc/zshrc
echo 'setopt appendhistory' >> /etc/zshrc
echo '' >> /etc/zshrc

echo '[ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"' >> /etc/zshrc
echo '' >> /etc/zshrc

echo '[ -f /usr/bin/starship ] && eval "$(starship init zsh)"' >> /etc/zshrc
echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> /etc/zshrc

# fsh
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting /usr/share/fsh

echo 'source /usr/share/fsh/fast-syntax-highlighting.plugin.zsh' >> /etc/zshrc
