# you forgot sudo didn't you?
alias please='sudo $(fc -ln -1)'

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
alias localip="ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'"
alias wanip='curl icanhazip.com'
alias dnstop='dnstop -l 5  eth1'
alias ethtool='ethtool eth1'
alias iftop='iftop -i eth1'
alias ports='netstat -tulanp | sort -t: -k2 -n'
alias tcpdump='tcpdump -i eth1'
alias vnstat='vnstat -i eth1'

# Python bullshit
alias python='pyton3'
alias pip='pip3'
alias pipup='pip install --upgrade pip'
alias pyenv='python -m venv ./venv'
alias pyact='source ./venv/bin/activate'

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
