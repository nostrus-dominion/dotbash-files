# Bash configuration for jumpbox.
[[ $- == *i* ]] || return 0
[[ ! -r $HOME/.bash_common ]] || source "$HOME/.bash_common"
PS1='\[\e[35m\]\u\[\e[m\]\[\e[35m\]@\[\e[m\]\[\e[35m\]\h\[\e[m\]:\W\$\[\e[37m\] \[\e[m\]'
