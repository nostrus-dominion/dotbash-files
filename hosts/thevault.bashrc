# Bash configuration for thevault.
[[ $- == *i* ]] || return 0
[[ ! -r $HOME/.bash_common ]] || source "$HOME/.bash_common"
PS1='\[\e[38;5;226m\]\u@\h\[\e[0m\]:\W\$ '
export NVM_DIR="$HOME/.nvm"
[[ ! -s "$NVM_DIR/nvm.sh" ]] || source "$NVM_DIR/nvm.sh"
[[ ! -s "$NVM_DIR/bash_completion" ]] || source "$NVM_DIR/bash_completion"
