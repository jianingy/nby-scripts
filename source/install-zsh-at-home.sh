#!/bin/bash

# filename   : install-zsh.sh
# created at : 2013-04-22 11:33:11
# author     : Jianing Yang <jianingy.yang AT gmail DOT com>

if [ ! -x /bin/zsh ]; then
    [ -f /etc/redhat-release ] && sudo yum install -y zsh
    [ -f /etc/debian_version ] && sudo apt-get install -y zsh
    [ -f /etc/arch_release ] && sudo pacman -S --noconfirm zsh
fi

if [ ! -x /bin/zsh ]; then
    echo "/bin/zsh not found. please install it manually."
    exit 111
fi

git clone git://github.com/jianingy/zsh-trip ~/.zsh || exit 112
ln -sf ~/.zsh/zshrc ~/.zshrc || exit 113
chsh -s /bin/zsh || exit 114
