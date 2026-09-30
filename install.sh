#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

usage() {
    cat <<'EOF'
Usage: bash install.sh

Run normally to install the Bash configuration for the current user.
Run as root (or with sudo) to install only the managed root prompt.
EOF
}

if (( $# != 0 )); then
    if (( $# == 1 )) && [[ $1 == -h || $1 == --help ]]; then
        usage
        exit 0
    fi

    usage >&2
    exit 2
fi

install_root() {
    local target=/root/.bashrc
    local stamp
    local backup
    local prompt_line
    local tmp

    prompt_line='export PS1="\[\033[38;5;160m\][\u@\h\[$(tput sgr0)\]:\[$(tput sgr0)\]\[\033[38;5;27m\]\w\[$(tput sgr0)\]\[\033[38;5;196m\]]\\$\[$(tput sgr0)\] \[$(tput sgr0)\]"'

    echo "dotbash-files installer"
    echo "Installing ROOT prompt into /root/.bashrc"
    echo
    printf 'Continue? [y/N] '
    read -r answer </dev/tty || exit 1
    [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || {
        echo 'Cancelled.'
        exit 1
    }

    stamp=$(date '+%Y%m%d-%H%M%S')
    backup="/root/.bashrc.dotbash-backup-$stamp"

    if [[ -e $target || -L $target ]]; then
        cp -a -- "$target" "$backup"
    else
        touch -- "$target"
    fi

    tmp=$(mktemp)

    awk '
        $0 == "# >>> dotbash-files root prompt >>>" { skip=1; next }
        $0 == "# <<< dotbash-files root prompt <<<" { skip=0; next }
        !skip { print }
    ' "$target" > "$tmp"

    {
        cat "$tmp"
        [[ ! -s $tmp ]] || printf '\n'
        echo '# >>> dotbash-files root prompt >>>'
        printf '%s\n' "$prompt_line"
        echo '# <<< dotbash-files root prompt <<<'
    } > "$target"

    rm -f -- "$tmp"

    printf 'Installed root prompt into %s. Backup: %s\n' "$target" "$backup"
}

color_names=(
    "Red"
    "Green"
    "Yellow"
    "Blue"
    "Magenta"
    "Cyan"
    "White"
    "Bright Red"
    "Bright Green"
    "Bright Yellow"
    "Bright Blue"
    "Bright Magenta"
    "Bright Cyan"
    "Bright White"
    "Orange"
    "256 Cyan"
    "256 Yellow"
)

color_sgr=(
    "31"
    "32"
    "33"
    "34"
    "35"
    "36"
    "37"
    "91"
    "92"
    "93"
    "94"
    "95"
    "96"
    "97"
    "38;5;208"
    "38;5;51"
    "38;5;226"
)

SELECTED_SGR=''

print_color_menu() {
    local row
    local column
    local option
    local index

    echo >/dev/tty
    echo "Colors:" >/dev/tty
    echo >/dev/tty

    for (( row = 0; row < 6; row++ )); do
        for (( column = 0; column < 3; column++ )); do
            option=$((row + 1 + column * 6))

            if (( option <= ${#color_names[@]} )); then
                index=$((option - 1))
                printf '  %2d) \033[%sm%-16s\033[0m' \
                    "$option" "${color_sgr[index]}" "${color_names[index]}" >/dev/tty
            else
                printf '  %2d) %-16s' "$option" "Custom ANSI-256" >/dev/tty
            fi

            (( column < 2 )) && printf '  ' >/dev/tty
        done

        echo >/dev/tty
    done

    echo >/dev/tty
}

select_color() {
    local label=$1
    local choice
    local custom

    while true; do
        printf '%s color: ' "$label" >/dev/tty
        read -r choice </dev/tty || exit 1

        if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#color_names[@]} )); then
            SELECTED_SGR=${color_sgr[choice - 1]}
            return 0
        fi

        if [[ $choice == 18 ]]; then
            printf 'ANSI-256 color number [0-255]: ' >/dev/tty
            read -r custom </dev/tty || exit 1

            if [[ $custom =~ ^[0-9]+$ ]] && (( custom >= 0 && custom <= 255 )); then
                SELECTED_SGR="38;5;$custom"
                return 0
            fi

            echo 'Invalid ANSI-256 color number.' >/dev/tty
            continue
        fi

        echo 'Invalid selection.' >/dev/tty
    done
}

install_user() {
    local user_sgr
    local host_sgr
    local stamp
    local backup_dir
    local target
    local source
    local command_name
    local prompt_file
    local username
    local hostname
    local directory
    local i

    echo "dotbash-files installer"

    prompt_file="$HOME/.bash_prompt"
    change_prompt=true

    if [[ -e $prompt_file || -L $prompt_file ]]; then
        echo >/dev/tty
        printf 'Existing prompt scheme found. Change prompt colors? [y/N] ' >/dev/tty
        read -r answer </dev/tty || exit 1

        if [[ $answer == [yY] || $answer == [yY][eE][sS] ]]; then
            change_prompt=true
        else
            change_prompt=false
            echo 'Keeping existing prompt scheme.' >/dev/tty
        fi
    fi

    if [[ $change_prompt == true ]]; then
        print_color_menu

        select_color "Username"
        user_sgr=$SELECTED_SGR

        select_color "Hostname"
        host_sgr=$SELECTED_SGR

        username=$(id -un)
        hostname=$(hostname -s)
        directory=$(basename -- "$PWD")

        echo >/dev/tty
        printf 'Prompt preview: \033[%sm%s\033[0m@\033[%sm%s\033[0m:%s$ command\n' \
            "$user_sgr" "$username" "$host_sgr" "$hostname" "$directory" >/dev/tty
    fi

    echo >/dev/tty
    printf 'Continue? [y/N] ' >/dev/tty
    read -r answer </dev/tty || exit 1
    [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || {
        echo 'Cancelled.'
        exit 1
    }

    stamp=$(date '+%Y%m%d-%H%M%S')
    backup_dir="$HOME/.bash-backup-$stamp"

    if [[ -e $backup_dir ]]; then
        printf 'Backup directory already exists: %s\n' "$backup_dir" >&2
        exit 1
    fi

    mkdir -- "$backup_dir"

    sources=(
        "$repo_dir/.bashrc"
        "$repo_dir/.bash_common"
        "$repo_dir/.bash_exports"
        "$repo_dir/.bash_aliases"
        "$repo_dir/.bash_functions"
    )

    targets=(
        "$HOME/.bashrc"
        "$HOME/.bash_common"
        "$HOME/.bash_exports"
        "$HOME/.bash_aliases"
        "$HOME/.bash_functions"
    )

    for i in "${!targets[@]}"; do
        target=${targets[i]}

        if [[ -e $target || -L $target ]]; then
            mv -- "$target" "$backup_dir/$(basename -- "$target")"
        fi

        ln -s -- "${sources[i]}" "$target"
    done

    if [[ $change_prompt == true ]]; then
        if [[ -e $prompt_file || -L $prompt_file ]]; then
            mv -- "$prompt_file" "$backup_dir/.bash_prompt"
        fi

        prompt_definition="PS1='\\[\\e[${user_sgr}m\\]\\u\\[\\e[0m\\]@\\[\\e[${host_sgr}m\\]\\h\\[\\e[0m\\]:\\W\\$ '"
        printf '%s\n' "$prompt_definition" > "$prompt_file"

        if ! bash -n "$prompt_file"; then
            echo "Error: generated prompt is invalid." >&2
            exit 1
        fi

        chmod 0644 -- "$prompt_file"
    fi

    # Create the local override file once, then leave it entirely user-owned.
    if [[ ! -e $HOME/.bash_local && ! -L $HOME/.bash_local ]]; then
        : > "$HOME/.bash_local"
        chmod 0600 -- "$HOME/.bash_local"
    fi

    # Retire the old optional-module link/directory from previous installs.
    legacy_functions_dir="$HOME/.bash_functions.d"
    if [[ -e $legacy_functions_dir || -L $legacy_functions_dir ]]; then
        mv -- "$legacy_functions_dir" "$backup_dir/.bash_functions.d"
    fi

    # Link standalone commands and remember exactly which names this repo owns.
    bin_dir="$HOME/.local/bin"
    state_dir="$HOME/.local/share/dotbash-files"
    manifest="$state_dir/bin-manifest"
    mkdir -p -- "$bin_dir" "$state_dir"

    current_commands=()
    if [[ -d $repo_dir/bin ]]; then
        for source in "$repo_dir"/bin/*; do
            [[ -f $source ]] || continue
            current_commands+=("$(basename -- "$source")")
        done
    fi

    is_current_command() {
        local candidate=$1
        local owned_command

        for owned_command in "${current_commands[@]}"; do
            [[ $candidate == "$owned_command" ]] && return 0
        done

        return 1
    }

    # Names previously installed by this repo. git-clean predates the manifest.
    stale_candidates=(git-clean)

    if [[ -r $manifest ]]; then
        while IFS= read -r command_name; do
            [[ -n $command_name && $command_name != */* ]] || continue
            stale_candidates+=("$command_name")
        done < "$manifest"
    fi

    for command_name in "${stale_candidates[@]}"; do
        is_current_command "$command_name" && continue

        target="$bin_dir/$command_name"

        if [[ -e $target || -L $target ]]; then
            printf 'Retiring stale dotbash command: %s\n' "$command_name"
            mv -- "$target" "$backup_dir/bin-$command_name"
        fi
    done

    if [[ -d $repo_dir/bin ]]; then
        for source in "$repo_dir"/bin/*; do
            [[ -f $source ]] || continue

            command_name=$(basename -- "$source")
            target="$bin_dir/$command_name"

            if [[ -e $target || -L $target ]]; then
                mv -- "$target" "$backup_dir/bin-$command_name"
            fi

            ln -s -- "$source" "$target"
        done
    fi

    printf '%s\n' "${current_commands[@]}" > "$manifest"

    printf 'Installed. Previous files (if any): %s\nOpen a new Bash terminal to load the settings.\n' "$backup_dir"
}

if (( EUID == 0 )); then
    install_root
else
    install_user
fi
