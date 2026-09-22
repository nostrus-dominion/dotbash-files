# ~/.bash_functions
#
# Personal Bash utility functions.
#
# Optional dependencies used by individual functions:
#   bc, curl, ffmpeg, git, jq, lsof, lynx, pygmentize, rsync, 7z
#   tar, unzip, bzip2, gzip, unrar, xz-utils, ImageMagick
#   yt-dlp (see .bash_functions.d/ytdl.bash)
#
# File managers supported by open():
#   dolphin, nautilus, thunar, pcmanfm


# ============================================================================
# General utilities
# ============================================================================

# Re-run the last simple command with sudo after showing exactly what will run.
# Bash history may include complex syntax, so this requires explicit approval.
please() {
    local previous
    previous=$(fc -ln -1) || return 1
    printf 'Run with sudo: %s\n' "$previous"
    local answer
    read -r -p 'Continue? [y/N] ' answer
    [[ "$answer" == [yY] ]] || return 1
    sudo bash -c "$previous"
}

# Use the default IPv4 route to find the active interface unless specified.
default-interface() {
    local interface
    interface=$(ip -4 route show default | awk '$1 == "default" {print $5; exit}')
    [[ -n "$interface" ]] || { echo 'No default IPv4 interface found.' >&2; return 1; }
    printf '%s\n' "$interface"
}

dnstop() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command dnstop -l 5 "$interface"; }
ethtool() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command ethtool "$interface"; }
iftop() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command iftop -i "$interface"; }
tcpdump() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command tcpdump -i "$interface"; }
vnstat() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command vnstat -i "$interface"; }

# Print aliases and functions from common Bash configuration files.
all-aliases() {
    local files=(
        "$HOME/.bashrc"
        "$HOME/.bash_aliases"
        "$HOME/.bash_functions"
    )

    local file

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            printf 'Contents of %s:\n' "$file"
            grep '^alias ' "$file"

            if [[ "$file" == "$HOME/.bash_functions" ]]; then
                grep -E '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_-]*\(\)[[:space:]]*\{' "$file"
            fi

            echo
        else
            printf '%s does not exist.\n\n' "$file"
        fi
    done
}

# Open a directory with the first supported graphical file manager found.
open() {
    local path="${1:-.}"
    local fileManagers=(dolphin nautilus thunar pcmanfm)
    local manager

    if [[ ! -d "$path" ]]; then
        printf "Error: '%s' is not a directory.\n" "$path" >&2
        return 1
    fi

    for manager in "${fileManagers[@]}"; do
        if command -v "$manager" &>/dev/null; then
            "$manager" "$path" &>/dev/null &
            return 0
        fi
    done

    echo "No supported file manager found." >&2
    return 1
}

# URL-encode a string.
urlencode() {
    if [[ $# -eq 0 ]]; then
        return 1
    fi

    jq -nr --arg value "$*" '$value | @uri'
}

# Search DuckDuckGo from the terminal using lynx.
duckduckgo() {
    if ! command -v lynx &>/dev/null; then
        echo "Error: lynx is not installed or not in PATH." >&2
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        echo "Usage: duckduckgo <search terms>" >&2
        return 1
    fi

    lynx "https://lite.duckduckgo.com/lite/?q=$(urlencode "$*")"
}

# Command-line calculator.
calc() {
    if ! command -v bc &>/dev/null; then
        echo "Error: bc is not installed or not in PATH." >&2
        return 1
    fi

    bc -l <<< "$*"
}

# Display weather from wttr.in.
weather() {
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is not installed or not in PATH." >&2
        return 1
    fi

    local location="${1:-}"

    if [[ -n "$location" ]]; then
        curl -fsS "https://wttr.in/${location}"
    else
        curl -fsS "https://wttr.in/"
    fi
}


# ============================================================================
# Files, directories, and archives
# ============================================================================

# Create a directory and enter it.
mkcd() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: mkcd <directory>"
        return 1
    fi

    mkdir -p -- "$1" || return 1
    cd -P -- "$1" || return 1
}

# Find files/directories whose names contain the supplied text.
search() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: search <search_term>"
        return 1
    fi

    find . -name "*$*"
}

# Stores all files, directories, and subdirectories into an uncompressed zip file.
store() {
    if ! command -v 7z &>/dev/null; then
        echo "Error: 7z is not installed or not in PATH." >&2
        return 1
    fi

    local archive="store.zip"
    local cutoff

    if [[ -e "$archive" ]]; then
        echo "Error: '$archive' already exists."
        echo "Remove it first if you want to create a new archive."
        return 1
    fi

    # No argument: store everything.
    if [[ $# -eq 0 ]]; then
        shopt -s dotglob nullglob
        local files=(*)
        shopt -u dotglob nullglob

        if [[ ${#files[@]} -eq 0 ]]; then
            echo "Nothing to store."
            return 1
        fi

        7z a -tzip -mx=0 "$archive" "${files[@]}"
        return $?
    fi

    # Convert the supplied date expression into a timestamp.
    if ! cutoff=$(date -d "$*" '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then
        echo "Error: invalid date/time expression: $*" >&2
        return 1
    fi

    # Find everything modified ON or BEFORE the cutoff.
    #
    # We use a temporary file because 7z's @list-file syntax lets it
    # preserve the complete relative path for every item.
    local listFile
    listFile=$(mktemp) || {
        echo "Error: unable to create temporary file." >&2
        return 1
    }


    find . -mindepth 1 -not -newermt "$cutoff" -print0 |
        while IFS= read -r -d '' file; do
            printf '%s\n' "${file#./}"
        done > "$listFile"

    if [[ ! -s "$listFile" ]]; then
        echo "Nothing to store before: $cutoff"
        rm -f -- "$listFile"
        return 1
    fi

    7z a -tzip -mx=0 "$archive" @"$listFile"
    local result=$?
    rm -f -- "$listFile"
    return "$result"
}

# Extract a supported archive into the current directory.
extract() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi

    local archive="$1"

    if [[ ! -f "$archive" ]]; then
        printf "Error: '%s' is not a valid file.\n" "$archive" >&2
        return 1
    fi

    case "$archive" in
        *.tar.bz2|*.tbz2)
            tar xjf -- "$archive"
            ;;
        *.tar.gz|*.tgz)
            tar xzf -- "$archive"
            ;;
        *.tar.xz|*.txz)
            tar xJf -- "$archive"
            ;;
        *.tar)
            tar xf -- "$archive"
            ;;
        *.bz2)
            bunzip2 -- "$archive"
            ;;
        *.gz)
            gunzip -- "$archive"
            ;;
        *.rar)
            unrar x -- "$archive"
            ;;
        *.zip)
            unzip -- "$archive"
            ;;
        *.7z)
            7z x -- "$archive"
            ;;
        *.Z)
            uncompress -- "$archive"
            ;;
        *)
            printf "Error: '%s' cannot be extracted by extract().\n" "$archive" >&2
            return 1
            ;;
    esac
}

# Convert PNG files to JPG without metadata.
png2jpg() {
    if ! command -v convert &>/dev/null && ! command -v magick &>/dev/null; then
        echo "Error: ImageMagick is not installed or not in PATH." >&2
        return 1
    fi

    shopt -s nullglob
    local files=(*.png)
    shopt -u nullglob

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No PNG files found."
        return 1
    fi

    mkdir -p jpg || return 1

    local file output
    for file in "${files[@]}"; do
        output="jpg/${file%.png}.jpg"

        if command -v magick &>/dev/null; then
            magick "$file" -strip "$output" || return 1
        else
            convert "$file" -strip "$output" || return 1
        fi
    done

    echo "Conversion complete! JPGs are in the 'jpg' folder."
}

# Rename PNG files using their filesystem modification timestamps.
fixtime() {
    shopt -s nullglob
    local files=(*.png)
    shopt -u nullglob

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No PNG files found."
        return 1
    fi

    local file timestamp output

    for file in "${files[@]}"; do
        timestamp=$(date -r "$file" '+%Y-%-m-%-d-%H%M%S')
        output="AIsuka-${timestamp}.${file##*.}"

        if [[ "$file" == "$output" ]]; then
            continue
        fi

        if [[ -e "$output" ]]; then
            printf "Skipping '%s': target '%s' already exists.\n" "$file" "$output" >&2
            continue
        fi

        mv -- "$file" "$output" || return 1
    done
}


# ============================================================================
# Process and system utilities
# ============================================================================

# Find processes using a TCP/UDP port and terminate them gracefully.
freeport() {
    if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+$ || "$1" -lt 1 || "$1" -gt 65535 ]]; then
        echo "Usage: freeport <port>"
        return 1
    fi

    local port="$1"
    local pids

    if ! command -v lsof &>/dev/null; then
        echo "Error: lsof is not installed or not in PATH." >&2
        return 1
    fi

    pids=$(lsof -t -i :"$port" 2>/dev/null | sort -u)

    if [[ -z "$pids" ]]; then
        echo "No process found using port $port."
        return 0
    fi

    echo "Processes using port $port:"
    lsof -nP -i :"$port"
    echo

    local pid
    for pid in $pids; do
        printf 'Sending TERM to PID %s...\n' "$pid"
        kill "$pid" 2>/dev/null || {
            printf 'Warning: could not terminate PID %s.\n' "$pid" >&2
        }
    done

    sleep 1

    local remaining
    remaining=$(lsof -t -i :"$port" 2>/dev/null | sort -u)

    if [[ -z "$remaining" ]]; then
        echo "Port $port is now free."
        return 0
    fi

    echo "Port $port is still in use:"
    lsof -nP -i :"$port"
    echo
    echo "If necessary, terminate the remaining process(es) manually."
    return 1
}

# Show the top 10 commands from Bash history.
history10() {
    echo "Top 10 most commonly used commands:"
    echo

    history |
        sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' |
        sed -E 's/^[[:space:]]*sudo[[:space:]]+//' |
        awk '
            {
                command = $1
                if (command != "") {
                    count[command]++
                    total++
                }
            }
            END {
                for (command in count) {
                    printf "%7d %6.2f%% %s\n", count[command], count[command] / total * 100, command
                }
            }
        ' |
        sort -nr |
        head -n 10
}

# Clear the current Bash history and history file.
clear_history() {
    : > "$HOME/.bash_history"
    history -c
    history -w
}

# Make rsync ding when a successful non-dry-run completes.
rsync() {
    command rsync "$@"
    local exitCode=$?

    if [[ $exitCode -eq 0 && -t 1 ]]; then
        local isDryRun=false
        local arg

        for arg in "$@"; do
            if [[ "$arg" == "--dry-run" || "$arg" == "-n" ]]; then
                isDryRun=true
                break
            fi
        done

        if [[ "$isDryRun" == false ]]; then
            printf '\a'
        fi
    fi

    return "$exitCode"
}

# Colorize a source file with pygmentize and view it with less.
lesscode() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: lesscode <file>"
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        printf "Error: '%s' is not a file.\n" "$1" >&2
        return 1
    fi

    if ! command -v pygmentize &>/dev/null; then
        echo "Error: pygmentize is not installed or not in PATH." >&2
        return 1
    fi

    pygmentize -g -O style=vim "$1" | less -R
}


# ============================================================================
# Package management
# ============================================================================

# Find the first supported package manager installed on the system.
detect-package-manager() {
    local managers=(
        apt
        dnf
        yum
        pacman
        apk
        emerge
        zypper
    )

    local manager

    for manager in "${managers[@]}"; do
        if command -v "$manager" &>/dev/null; then
            printf '%s\n' "$manager"
            return 0
        fi
    done

    echo "Error: Cannot detect a supported package manager on $(uname -s) $(uname -r)." >&2
    return 2
}

# Check for and optionally install system updates.
up() {
    local packageManager
    packageManager=$(detect-package-manager) || return $?

    echo "Detected package manager: $packageManager"
    echo "Checking for updates..."
    echo

    local updates response updateStatus

    case "$packageManager" in
        apt)
            sudo apt update || {
                echo "Error: apt update failed." >&2
                return 1
            }

            updates=$(apt-get -s upgrade | awk '/^Inst / {print $2}')

            if [[ -z "$updates" ]]; then
                echo "System is already up to date."
                return 0
            fi

            echo "Updates available:"
            echo
            printf '%s\n' "$updates"
            echo

            read -r -p "Upgrade these packages? [y/N] " response

            case "$response" in
                [yY]|[yY][eE][sS])
                    echo
                    sudo apt upgrade
                    ;;
                *)
                    echo "Upgrade cancelled."
                    ;;
            esac
            ;;

        dnf)
            sudo dnf check-update
            updateStatus=$?

            case "$updateStatus" in
                0)
                    echo "System is already up to date."
                    ;;
                100)
                    echo
                    read -r -p "Install available updates? [y/N] " response

                    case "$response" in
                        [yY]|[yY][eE][sS])
                            echo
                            sudo dnf upgrade
                            ;;
                        *)
                            echo "Upgrade cancelled."
                            ;;
                    esac
                    ;;
                *)
                    echo "Error: dnf check-update failed." >&2
                    return "$updateStatus"
                    ;;
            esac
            ;;

        yum)
            sudo yum check-update
            updateStatus=$?

            case "$updateStatus" in
                0)
                    echo "System is already up to date."
                    ;;
                100)
                    echo
                    read -r -p "Install available updates? [y/N] " response

                    case "$response" in
                        [yY]|[yY][eE][sS])
                            echo
                            sudo yum update
                            ;;
                        *)
                            echo "Upgrade cancelled."
                            ;;
                    esac
                    ;;
                *)
                    echo "Error: yum check-update failed." >&2
                    return "$updateStatus"
                    ;;
            esac
            ;;

        pacman)
            updates=$(pacman -Qu 2>/dev/null)

            if [[ -z "$updates" ]]; then
                echo "System is already up to date."
                return 0
            fi

            echo "Updates available:"
            echo
            printf '%s\n' "$updates"
            echo

            read -r -p "Upgrade these packages? [y/N] " response

            case "$response" in
                [yY]|[yY][eE][sS])
                    echo
                    sudo pacman -Syu
                    ;;
                *)
                    echo "Upgrade cancelled."
                    ;;
            esac
            ;;

        apk)
            sudo apk update || {
                echo "Error: apk update failed." >&2
                return 1
            }

            echo
            read -r -p "Upgrade installed packages? [y/N] " response

            case "$response" in
                [yY]|[yY][eE][sS])
                    echo
                    sudo apk upgrade
                    ;;
                *)
                    echo "Upgrade cancelled."
                    ;;
            esac
            ;;

        emerge)
            echo "Portage does not have a universal non-interactive update check here."
            echo

            read -r -p "Sync repositories and update @world? [y/N] " response

            case "$response" in
                [yY]|[yY][eE][sS])
                    echo
                    sudo emerge --sync && sudo emerge -avuDU @world
                    ;;
                *)
                    echo "Upgrade cancelled."
                    ;;
            esac
            ;;

        zypper)
            sudo zypper refresh || {
                echo "Error: zypper refresh failed." >&2
                return 1
            }

            echo
            read -r -p "Install available updates? [y/N] " response

            case "$response" in
                [yY]|[yY][eE][sS])
                    echo
                    sudo zypper update
                    ;;
                *)
                    echo "Upgrade cancelled."
                    ;;
            esac
            ;;

        *)
            echo "Error: Unsupported package manager: $packageManager" >&2
            return 2
            ;;
    esac
}


# ============================================================================
# Git
# ============================================================================

# Reset the local master branch to upstream/master and force-push origin/master.
#
# This is intentionally guarded because it destroys local commits/changes and
# rewrites the remote branch.
reset-master-branch() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Error: This is not a Git repository." >&2
        return 1
    fi

    local currentBranch
    currentBranch=$(git branch --show-current)

    if [[ "$currentBranch" != "master" ]]; then
        printf "Error: You are currently on '%s', not 'master'.\n" "$currentBranch" >&2
        return 1
    fi

    if ! git remote get-url upstream &>/dev/null; then
        echo "Error: No 'upstream' remote is configured." >&2
        return 1
    fi

    if ! git remote get-url origin &>/dev/null; then
        echo "Error: No 'origin' remote is configured." >&2
        return 1
    fi

    echo "WARNING: This will:"
    echo "  1. Fetch upstream/master"
    echo "  2. Reset local master to upstream/master"
    echo "  3. Force-push origin/master"
    echo
    echo "Any commits on local master that are not in upstream/master will be lost"
    echo "from the local branch, and origin/master will be rewritten."
    echo

    if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
        echo "Error: Working tree has changes or untracked files. Commit, stash, or remove them first." >&2
        return 1
    fi

    # Confirm the upstream ref exists before resetting the local branch.
    git fetch upstream master || return 1
    git rev-parse --verify 'refs/remotes/upstream/master^{commit}' >/dev/null || return 1

    read -r -p "Type RESET to continue: " confirmation

    if [[ "$confirmation" != "RESET" ]]; then
        echo "Operation cancelled."
        return 1
    fi

    git reset --hard upstream/master || return 1
    git push origin master --force-with-lease
}


# ============================================================================
# Services
# ============================================================================

# Activate the first venv*/bin/activate found in the current directory.
pyact() {
    shopt -s nullglob
    local matches=(./venv*/bin/activate)
    shopt -u nullglob

    if [[ ${#matches[@]} -eq 0 ]]; then
        printf "No venv*/bin/activate found in %s\n" "$PWD" >&2
        return 1
    fi

    if [[ ${#matches[@]} -gt 1 ]]; then
        echo "Multiple virtual environments found:"
        printf '  %s\n' "${matches[@]}"
        echo
        echo "Please activate one manually or remove the ambiguity."
        return 1
    fi

    local venvPath="${matches[0]}"
    local venvName
    venvName=$(basename "$(dirname "$(dirname "$venvPath")")")

    read -r -p "Activate $venvName? [y/N] " answer

    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            source "$venvPath"
            echo "Activated $venvName"
            ;;
        *)
            echo "Activation cancelled."
            return 1
            ;;
    esac
}


# Optional machine-specific commands. Install this directory beside this file.
for _bash_functions_module in "$HOME"/.bash_functions.d/*.bash; do
    [[ -f "$_bash_functions_module" ]] || continue
    # shellcheck source=/dev/null
    source "$_bash_functions_module"
done
unset _bash_functions_module
