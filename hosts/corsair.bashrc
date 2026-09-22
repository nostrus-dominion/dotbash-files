# Bash configuration for corsair.
[[ $- == *i* ]] || return 0
if [[ -r $HOME/.bash_common ]]; then
    source "$HOME/.bash_common" || return $?
fi
PS1='\[\e[32m\]\u\[\e[m\]\[\e[32m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\]:\W\$ '
