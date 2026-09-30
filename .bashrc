# Generic interactive Bash entry point installed by dotbash-files.
[[ $- == *i* ]] || return 0

if [[ -r $HOME/.bash_common ]]; then
    source "$HOME/.bash_common" || return $?
fi

# User-owned machine settings always have the final say.
if [[ -r $HOME/.bash_local ]]; then
    source "$HOME/.bash_local" || return $?
fi
