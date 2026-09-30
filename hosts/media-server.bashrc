# Bash configuration for media-server.
[[ $- == *i* ]] || return 0
if [[ -r $HOME/.bash_common ]]; then
    source "$HOME/.bash_common" || return $?
fi
PS1='\[\e[38;5;51m\]\u@\h:\[\e[0m\]\W\$ '

