# ~/.bash_functions
#
# Personal Bash utility functions.
#
# Optional dependencies used by individual functions:
#   bc, curl, jq, lynx, pygmentize, rsync, 7z
#   tar, pigz, unzip, bzip2, gzip, unrar, xz-utils, ImageMagick
#
# File managers supported by open():
#   dolphin, nautilus, thunar, pcmanfm

# An existing interactive shell may still have aliases from an older config.
# Remove names that are functions below before Bash parses their definitions.
unalias please dnstop ethtool iftop tcpdump vnstat pyact tmpd man zipit store targz rm 2>/dev/null || :


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

# Run dnstop on the default IPv4 interface unless one is specified.
dnstop() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command dnstop -l 5 "$interface"; }
# Show ethtool information for the default IPv4 interface unless one is specified.
ethtool() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command ethtool "$interface"; }
# Run iftop on the default IPv4 interface unless one is specified.
iftop() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command iftop -i "$interface"; }
# Capture packets on the default IPv4 interface unless one is specified.
tcpdump() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command tcpdump -i "$interface"; }
# Show vnStat data for the default IPv4 interface unless one is specified.
vnstat() { local interface="${1:-$(default-interface)}"; [[ -n "$interface" ]] && command vnstat -i "$interface"; }

# Show local IPv4 addresses and the public IPv4 address.
myip() {
    (( $# == 0 )) || { echo 'Usage: myip' >&2; return 2; }
    echo 'Local IPv4:'
    ip -brief -4 address show up || return
    echo 'Public IPv4:'
    curl -4fsS --max-time 5 https://icanhazip.com
}

# Show the 20 largest files in the current directory tree or a given directory.
largest() {
    (( $# <= 1 )) || { echo 'Usage: largest [directory]' >&2; return 2; }
    local directory=${1:-$PWD}
    [[ -d $directory ]] || { printf 'Not a directory: %s\n' "$directory" >&2; return 1; }
    local entry bytes filename
    while IFS= read -r -d '' entry; do
        bytes=${entry%%$'\t'*}
        filename=${entry#*$'\t'}
        printf '%8s  %s\n' "$(numfmt --to=iec --suffix=B "$bytes")" "$filename"
    done < <(find "$directory" -type f -printf '%s\t%p\0' | sort -z -t $'\t' -k1,1nr | head -z -n 20)
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

# Catch a mistyped sudo and offer to run the intended command.
suod() {
    read -rp "Did you mean sudo? [y/N] " answer

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        sudo "$@"
    else
        echo "Well then learn to type dumbass"
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

# Create a temporary directory and enter it.
tmpd() {
    if (( $# > 1 )); then
        echo 'Usage: tmpd [name]' >&2
        return 2
    fi

    local directory

    if (( $# == 0 )); then
        directory=$(mktemp -d) || return 1
    else
        directory=$(mktemp -d -t "$1.XXXXXXXXXX") || return 1
    fi

    cd -P -- "$directory" || return 1
}

# Protect recursive force-deletes with an explicit confirmation.
rm() {
    local recursive=false
    local force=false
    local arg

    for arg in "$@"; do
        case "$arg" in
        --recursive|-*r*|-*R*)
            recursive=true
            ;;
        esac

        case "$arg" in
        --force|-*f*)
            force=true
            ;;
        esac
    done

    if [[ "$recursive" == true && "$force" == true ]]; then
        echo "WARNING: You are about to recursively force-delete:"
        printf '  %q' "$@"
        echo

        local answer
        read -r -p "Are you sure? [y/N] " answer

        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            echo "Deletion cancelled."
            return 1
        fi
    fi

    command rm -I --preserve-root "$@"
}

# Find files/directories whose names contain the supplied text.
search() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: search <search_term>"
        return 1
    fi

    find . -name "*$*"
}

# Bundle the current directory into a fast, uncompressed ZIP archive.
# With a date expression, include only entries modified on or before that cutoff.
zipit() {
    if ! command -v 7z >/dev/null 2>&1; then
        echo "Error: 7z is not installed or not in PATH." >&2
        return 1
    fi

    local archive="zipit.zip"
    local cutoff

    if [[ -e $archive ]]; then
        printf "Error: '%s' already exists.\n" "$archive" >&2
        echo "Remove it first if you want to create a new archive." >&2
        return 1
    fi

    # No argument: bundle everything in the current directory.
    if (( $# == 0 )); then
        shopt -s dotglob nullglob
        local files=(*)
        shopt -u dotglob nullglob

        if (( ${#files[@]} == 0 )); then
            echo "Nothing to zip."
            return 1
        fi

        7z a -tzip -mx=0 "$archive" "${files[@]}"
        return $?
    fi

    # Convert the supplied date expression into a timestamp.
    if ! cutoff=$(date -d "$*" '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then
        printf 'Error: invalid date/time expression: %s\n' "$*" >&2
        return 1
    fi

    local list_file
    list_file=$(mktemp) || {
        echo "Error: unable to create temporary file." >&2
        return 1
    }

    find . -mindepth 1 -not -newermt "$cutoff" -print0 |
        while IFS= read -r -d '' file; do
            printf '%s\n' "${file#./}"
        done > "$list_file"

    if [[ ! -s $list_file ]]; then
        printf 'Nothing to zip on or before: %s\n' "$cutoff"
        command rm -f -- "$list_file"
        return 1
    fi

    7z a -tzip -mx=0 "$archive" @"$list_file"
    local result=$?
    command rm -f -- "$list_file"
    return "$result"
}

# Preserve the current Unix filesystem tree in an uncompressed TAR archive.
# With a date expression, include only entries modified on or before that cutoff.
store() {
    if ! command -v tar >/dev/null 2>&1; then
        echo "Error: tar is not installed or not in PATH." >&2
        return 1
    fi

    local archive="store.tar"
    local cutoff
    local list_file
    local result

    if [[ -e $archive ]]; then
        printf "Error: '%s' already exists.\n" "$archive" >&2
        echo "Remove it first if you want to create a new archive." >&2
        return 1
    fi

    # No argument: capture the current directory tree as-is.
    if (( $# == 0 )); then
        shopt -s dotglob nullglob
        local files=(*)
        shopt -u dotglob nullglob

        if (( ${#files[@]} == 0 )); then
            echo "Nothing to store."
            return 1
        fi

        tar -cf "$archive" -- "${files[@]}"
        return $?
    fi

    if ! cutoff=$(date -d "$*" '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then
        printf 'Error: invalid date/time expression: %s\n' "$*" >&2
        return 1
    fi

    # Build the list before creating store.tar so the archive never includes itself.
    # NUL-delimited names plus --no-recursion preserve unusual filenames and keep
    # the date filter exact instead of recursively pulling in newer descendants.
    list_file=$(mktemp) || {
        echo "Error: unable to create temporary file." >&2
        return 1
    }

    find . -mindepth 1 -not -newermt "$cutoff" -print0 > "$list_file"

    if [[ ! -s $list_file ]]; then
        printf 'Nothing to store on or before: %s\n' "$cutoff"
        command rm -f -- "$list_file"
        return 1
    fi

    tar -cf "$archive" --null --no-recursion --files-from="$list_file"
    result=$?
    command rm -f -- "$list_file"

    if (( result != 0 )); then
        command rm -f -- "$archive"
    fi

    return "$result"
}

# Create a compressed, portable .tar.gz archive of a file or directory.
# Uses pigz when available for multicore compression, otherwise gzip.
targz() {
    if (( $# != 1 )); then
        echo 'Usage: targz <file-or-directory>' >&2
        return 2
    fi

    if ! command -v tar >/dev/null 2>&1; then
        echo "Error: tar is not installed or not in PATH." >&2
        return 1
    fi

    local input=${1%/}
    local archive="${input}.tar.gz"
    local compressor
    local -a pipeline_status

    if [[ ! -e $input && ! -L $input ]]; then
        printf "Error: '%s' does not exist.\n" "$input" >&2
        return 1
    fi

    if [[ -e $archive ]]; then
        printf "Error: '%s' already exists.\n" "$archive" >&2
        return 1
    fi

    if command -v pigz >/dev/null 2>&1; then
        compressor=pigz
    else
        compressor=gzip
    fi

    printf 'Compressing with %s: %s -> %s\n' "$compressor" "$input" "$archive"

    tar -cf - --exclude='.DS_Store' --exclude='*/.DS_Store' -- "$input" |
        "$compressor" > "$archive"
    pipeline_status=("${PIPESTATUS[@]}")

    if (( pipeline_status[0] != 0 || pipeline_status[1] != 0 )); then
        command rm -f -- "$archive"
        echo 'Archive creation failed.' >&2
        return 1
    fi

    printf '%s created successfully.\n' "$archive"
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
            printf "Error: '%s' cannot be extracted by this command." "$archive" >&2
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

# Display man pages with colorized headings and emphasis.
man() {
    local man_bin
    man_bin=$(type -P man) || {
        echo 'Error: man is not installed or not in PATH.' >&2
        return 1
    }

    env \
        LESS_TERMCAP_mb="$(printf '\e[1;31m')" \
        LESS_TERMCAP_md="$(printf '\e[1;31m')" \
        LESS_TERMCAP_me="$(printf '\e[0m')" \
        LESS_TERMCAP_se="$(printf '\e[0m')" \
        LESS_TERMCAP_so="$(printf '\e[1;44;33m')" \
        LESS_TERMCAP_ue="$(printf '\e[0m')" \
        LESS_TERMCAP_us="$(printf '\e[1;32m')" \
        "$man_bin" "$@"
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

    case "$packageManager" in
        apt)
            sudo apt update && sudo apt upgrade
            ;;
        dnf)
            sudo dnf upgrade
            ;;
        yum)
            sudo yum update
            ;;
        pacman)
            sudo pacman -Syu
            ;;
        apk)
            # apk never asks for confirmation on its own, so --interactive is needed
            sudo apk update && sudo apk upgrade --interactive
            ;;
        emerge)
            sudo emerge --sync && sudo emerge --ask --update --deep --newuse @world
            ;;
        zypper)
            sudo zypper refresh && sudo zypper update
            ;;
        *)
            echo "Error: Unsupported package manager: $packageManager" >&2
            return 2
            ;;
    esac
}

# ============================================================================
# Python environments
# ============================================================================

# Create and activate a Python virtual environment in this shell.
mkvenv() {
    (( $# <= 1 )) || { echo 'Usage: mkvenv [directory]' >&2; return 2; }
    local directory=${1:-venv}
    if [[ -e $directory || -L $directory ]]; then
        printf 'Already exists: %s\n' "$directory" >&2
        return 1
    fi
    command -v python3 >/dev/null || { echo 'python3 is required.' >&2; return 1; }
    python3 -m venv "$directory" || return
    # shellcheck source=/dev/null
    source "$directory/bin/activate"
}

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
