# Bash configuration for seedbox.
[[ $- == *i* ]] || return 0
[[ ! -r $HOME/.bash_common ]] || source "$HOME/.bash_common"
PS1='\[\e[38;5;208m\]\u@\h\[\e[0m\]:\W\$ '
export SYSTEMD_EDITOR=vim
