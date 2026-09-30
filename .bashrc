# Generic interactive Bash entry point installed by dotbash-files.
[[ $- == *i* ]] || return 0

if [[ -r $HOME/.bash_common ]]; then
    source "$HOME/.bash_common" || return $?
fi

if [[ -r $HOME/.bash_prompt ]]; then
    source "$HOME/.bash_prompt" || return $?
fi
