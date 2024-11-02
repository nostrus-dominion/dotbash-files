# saftey nets
alias rm='rm -I --preserve-root'
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'

# system info
alias meminfo='free -m -l -t'
alias cpuinfo='lscpu'

## get top process eating stuff
alias psmem='ps auxf | sort -nr -k 4 | head -10'
alias pscpu='ps auxf | sort -nr -k 3 | head -10'

# cd command behavior
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'

# network stuff
alias ports='netstat -tulanp | sort -t: -k2 -n'
alias dnstop='dnstop -l 5  eth1'
alias vnstat='vnstat -i eth1'
alias iftop='iftop -i eth1'
alias tcpdump='tcpdump -i eth1'
alias ethtool='ethtool eth1'

# custom commands
alias path='echo -e ${PATH//:/\\n}'
alias serve='python3 -m http.server'
alias python='python3'
alias lsblk='lsblk -e 7'
alias alldisks='ls -lF /dev/disk/by-id/'
alias top='htop'
alias df='df -H'
alias du='du -ch'
