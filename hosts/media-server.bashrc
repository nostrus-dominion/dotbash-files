# Bash configuration for media-server.
[[ $- == *i* ]] || return 0
if [[ -r $HOME/.bash_common ]]; then
    source "$HOME/.bash_common" || return $?
fi
PS1='\[\e[38;5;51m\]\u@\h:\[\e[0m\]\W\$ '
alias stoparr="sudo systemctl stop radarr.service sonarr.service lidarr.service prowlarr.service"
alias startarr="sudo systemctl start radarr.service sonarr.service lidarr.service prowlarr.service"
alias tree="tree --dirsfirst -pughs"
