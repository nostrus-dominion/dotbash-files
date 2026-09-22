# Bash configuration for corsair.
[[ $- == *i* ]] || return 0
[[ ! -r $HOME/.bash_common ]] || source "$HOME/.bash_common"
PS1='\[\e[32m\]\u\[\e[m\]\[\e[32m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\]:\W\$ '
