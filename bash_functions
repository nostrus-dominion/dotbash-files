## These functions are assuming you have the following binaries installed
## bc, jq, lynx, tar, unzip, bzip2, gzip, p7zip-free, unrar-free, xz-utils
## Plus one of the following file explorers
## dolphin, nautilus, thunar, pcmanfm

# Prints all aliases and functions
all-aliases() {
  local files=(~/.bashrc ~/.bash_aliases ~/.bash_functions)
  for file in "${files[@]}"; do
    if [ -f "$file" ]; then
      echo "Contents of $file:"
      grep '^alias ' "$file"
      if [[ "$file" == *".bash_functions"* ]]; then
        grep '^[a-zA-Z_][a-zA-Z0-9_-]*() {' "$file"
      fi
        echo ""
      else
        echo "$file does not exist."
    fi
  done
}

# Open your working directory with a file manager
open() {
  local file_managers=(dolphin nautilus thunar pcmanfm)
  for manager in "${file_managers[@]}"; do
    if command -v "$manager" &> /dev/null; then
      "$manager" .
      return
    fi
  done
  echo "No supported file manager found."
}

# Query duckduckgo
urlencode() {
  local args="$@"
  jq -nr --arg v "$args" '$v|@uri'
}

duckduckgo() {
  lynx "https://lite.duckduckgo.com/lite/?q=$(urlencode "$@")"
}

# Command line calculator
calc() {
  bc -l <<< "$@"
}

# Finds the process that is using a port and kills it
freeport() {
  if [ -z "$1" ]; then
    echo "Usage: freeport <port>"
    return 1
  fi

  PORT=$1

  pid=$(lsof -i :$PORT -t)
  if [ -z "$pid" ]; then
    echo "No process found running on port $PORT"
  else
    echo "Killing process with PID $pid running on port $PORT"
    kill -9 $pid
    echo "Port $PORT is now free."
  fi
}

# Reset your git branch
reset-master-branch() {
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: This is not a Git repository."
    return 1
  fi

  echo "Make sure you have set the original remote as upstream. Do you wish to continue? (yes/no)"
  read confirmation

  confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')

  if [ "$confirmation" = "yes" ] || [ "$confirmation" = "y" ]; then
    git checkout master
    git pull upstream master
    git reset --hard upstream/master
    git push origin master --force
  else
    echo "Operation cancelled."
  fi
}

# Extracts a supported archive to the working directory
extract() {
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
      *.tar.gz)    tar xzf $1     ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar e $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xf $1      ;;
      *.tbz2)      tar xjf $1     ;;
      *.tgz)       tar xzf $1     ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Gets the weather from the nearest support location based on your WAN IP address
weather() {
  curl wttr.in/"$1"
}

# Makes a direcotry and goes into it
mkcd() {
  if [ -z "$1" ]; then
    # Display usage if no parameters are given.
    echo "mkcd: you are missing a directory name."
    echo "NAME"
    echo "    mkcd - create a directory and then go into it."
    echo "USAGE"
    echo "    mkcd <path/directory_name>"
    return 1
    fi
    mkdir -p -- "$1"
    cd -P -- "$1"
}

# Shows top 10 most commonly used commands from your bash history
history10() {
  echo "Top 10 your most commonly used commands:"
  echo
  history | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | grep -v "./" | column -c3 -s " " -t | sort -nr | nl | head -n10
}

# Finds all supported package managers on your system
detect-package-manager() {
  declare -A dist_release

  dist_release["/etc/redhat-release"]="yum"
  dist_release["/etc/arch-release"]="pacman"
  dist_release["/etc/gentoo-release"]="emerge"
  dist_release["/etc/SuSE-release"]="zypp"
  dist_release["/etc/debian_version"]="apt"
  dist_release["/etc/alpine-release"]="apk"

  for key in "${!dist_release[@]}"; do
    if [ -f "${key}" ]; then
      echo "${dist_release["${key}"]}"
      return 0
    fi
  done

  1>&2 echo "Cannot detect package manager on system $(uname -o) $(uname -r)"
  return 2
}

search() {
    if [ -z "$1" ]; then
        echo "Usage: search <search_term>"
        return 1
    fi

    local search_term="$1"

    # Define the directory to start the search from, e.g., current directory
    local start_dir="."

    # Execute the find command
    find "$start_dir" -name "*$search_term*"
}
