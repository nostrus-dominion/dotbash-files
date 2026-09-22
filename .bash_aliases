# `please` is a function in .bash_functions. Inspect and approve before running.

# saftey nets
alias chgrp='chgrp --preserve-root'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias cp='cp -riv'
alias mv='mv -i'
alias rm='rm -I --preserve-root'

# system info
alias cpuinfo='lscpu'
alias meminfo='free -m -l -t'
alias osinfo='cat /etc/os-release'

## get top process eating stuff
alias pscpu='ps auxf | sort -nr -k 3 | head -10'
alias psmem='ps auxf | sort -nr -k 4 | head -10'

# cd command behavior
alias cd..='cd ..'
alias .1='cd ..'
alias .2='cd ../../'
alias .3='cd ../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'
alias .r='cd /'

# network stuff
alias localip='ip -brief -4 address show'
alias wanip='curl icanhazip.com'
# ports is a function in .bash_functions and accepts an optional port.

# Python bullshit
alias python='python3'
alias pip='pip3'
alias pipup='pip install --upgrade pip'
alias pyenv='python -m venv ./venv'
# pyact is defined in .bash_functions and handles venv* directories.

# custom commands
alias rebash="source $HOME/.bashrc && echo Bash config reloaded"
alias cls='clear'
alias upgrade='sudo apt-get update --yes && sudo apt-get upgrade --yes'
alias fullupgrade='sudo apt-get update && sudo apt-get upgrade && sudo apt-get dist-upgrade && sudo apt autoclean && sudo apt autoremove'
alias clean='sudo apt-get autoclean && sudo apt-get autoremove'
alias path='echo -e ${PATH//:/\\n}'
alias serve='python3 -m http.server'
alias lsblk='lsblk -e 7'
alias alldisks='ls -lF /dev/disk/by-id/'
alias top='htop'
alias df='df -H'
alias du='du -ch'
alias files='echo && \
             echo -e "Count in\033[0;32m $PWD" && \
             echo -e "\033[0;31m$(find . -type f | wc -l)\033[1;37m files." && \
             echo -e "\033[0;34m$(find . -type d | wc -l)\033[1;37m directories." && \
             echo'
alias hgrep="history | grep"
alias wget-secure='wget --https-only --secure-protocol=PFS'
