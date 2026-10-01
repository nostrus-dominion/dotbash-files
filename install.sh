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

if [[ ${BASH_SOURCE[0]} == "$0" ]] && (( $# != 0 )); then
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

# Read installer metadata without executing a user's private shell code.
local_setting() {
    local key=$1
    [[ -r $HOME/.bash_local ]] || return 0
    sed -n "s/^# dotbash-${key}: //p" "$HOME/.bash_local" | tail -n 1
}

# Replace only the requested installer block. Keep arbitrary user code last.
write_local_block() {
    local label=$1 content=$2 tmp
    tmp=$(mktemp "$HOME/.bash-local.XXXXXXXX") || return 1
    {
        printf '# >>> dotbash-files %s >>>\n%s\n# <<< dotbash-files %s <<<\n\n' "$label" "$content" "$label"
        awk -v start="# >>> dotbash-files $label >>>" -v end="# <<< dotbash-files $label <<<" '
            $0 == start { skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
            END { if (skip) exit 1 }
        ' "$HOME/.bash_local"
    } > "$tmp" || { command rm -f -- "$tmp"; return 1; }
    bash -n "$tmp" || { command rm -f -- "$tmp"; return 1; }
    chmod 0600 -- "$tmp"
    command mv -- "$tmp" "$HOME/.bash_local"
}

setup_gitconfig() {
    command -v git >/dev/null 2>&1 || {
        echo 'Git is not installed; skipping Git identity setup.'
        return 0
    }

    local legacy="$HOME/.local/gitconfig" entry key value include_path
    local current_name current_email author_name author_email answer content helper
    local legacy_dir=${legacy%/*}

    # Git cannot parse Bash. Migrate the old include into native global config so
    # editors/GUI clients also retain it, including multi-valued custom settings.
    if [[ -f $legacy ]]; then
        git config --file "$legacy" --list >/dev/null || return 1
        cp -p -- "$legacy" "$backup_dir/gitconfig-local"
        if [[ -f $HOME/.gitconfig ]]; then
            cp -p -- "$HOME/.gitconfig" "$backup_dir/gitconfig-global"
        fi
        if [[ -f ${XDG_CONFIG_HOME:-$HOME/.config}/git/config ]]; then
            cp -p -- "${XDG_CONFIG_HOME:-$HOME/.config}/git/config" "$backup_dir/gitconfig-global-xdg"
        fi
        while IFS= read -r -d '' entry; do
            key=${entry%%$'\n'*}
            value=${entry#*$'\n'}
            if [[ $key == include.path || $key == includeif.*.path ]]; then
                # Relative includes used to resolve beside ~/.local/gitconfig.
                [[ $value == /* || $value == '~/'* ]] || value="$legacy_dir/$value"
            fi
            # Preserve native multi-valued settings, particularly credential helpers.
            git config --global --add "$key" "$value"
        done < <(git config --file "$legacy" --null --list)
        for include_path in "$legacy" '~/.local/gitconfig'; do
            git config --global --fixed-value --unset-all include.path "$include_path" || [[ $? == 5 ]]
        done
        command mv -- "$legacy" "$backup_dir/gitconfig-local-retired"
        echo 'Migrated ~/.local/gitconfig into native global Git configuration.'
    fi

    current_name=$(local_setting git-name)
    current_email=$(local_setting git-email)
    current_name=${current_name:-$(git config --global --get user.name 2>/dev/null || :)}
    current_email=${current_email:-$(git config --global --get user.email 2>/dev/null || :)}
    if [[ -n $current_name && -n $current_email ]]; then
        printf 'Existing Git identity: %s <%s>. Change it? [y/N] ' "$current_name" "$current_email" >/dev/tty
        read -r answer </dev/tty || return 1
        if [[ $answer != [yY] && $answer != [yY][eE][sS] ]]; then
            # Add a block on migration, but never reset a user's existing block.
            [[ -z $(local_setting git-name) ]] || return 0
            author_name=$current_name
            author_email=$current_email
        fi
    fi
    if [[ -z ${author_name:-} ]]; then
        while true; do
            printf 'Git author name [%s]: ' "$current_name" >/dev/tty
            read -r author_name </dev/tty || return 1
            author_name=${author_name:-$current_name}
            [[ -n $author_name ]] && break
        done
        while true; do
            printf 'Git author email [%s]: ' "$current_email" >/dev/tty
            read -r author_email </dev/tty || return 1
            author_email=${author_email:-$current_email}
            [[ -n $author_email ]] && break
        done
    fi

    # Updating the native config happens only in the installer, never at shell startup.
    git config --global --replace-all user.name "$author_name"
    git config --global --replace-all user.email "$author_email"
    if ! git config --global --get-all credential.helper >/dev/null 2>&1; then
        helper=cache
        [[ $(uname -s) != Darwin ]] || helper=osxkeychain
        git config --global credential.helper "$helper"
    fi
    printf -v content '# dotbash-git-name: %s\n# dotbash-git-email: %s\n# Shell identity overrides; native ~/.gitconfig also supports GUI clients.\nexport GIT_AUTHOR_NAME=%q\nexport GIT_AUTHOR_EMAIL=%q\nexport GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"\nexport GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"' \
        "$author_name" "$author_email" "$author_name" "$author_email"
    write_local_block git "$content"
}

setup_local() {
    local user_sgr host_sgr username hostname directory answer current_history history_choice
    local content prompt_definition legacy_history
    local local_file="$HOME/.bash_local"
    local prompt_file="$HOME/.bash_prompt"

    # Preserve a symlink's contents while making the local file independent of Git.
    if [[ -e $local_file || -L $local_file ]]; then
        [[ -f $local_file && -r $local_file ]] || {
            echo 'Error: ~/.bash_local must be a readable regular file.' >&2; return 1;
        }
        cp -pL -- "$local_file" "$backup_dir/.bash_local"
        if [[ -L $local_file ]]; then
            command rm -- "$local_file"
            cp -- "$backup_dir/.bash_local" "$local_file"
        fi
    else
        printf '# Private machine settings. Custom code below installer blocks wins.\n' > "$local_file"
    fi
    chmod 0600 -- "$local_file"

    # Import the old prompt before existing local code so custom PS1 still wins.
    if [[ -f $prompt_file ]]; then
        content=$(cat -- "$prompt_file")
        write_local_block prompt "$content"
        command mv -- "$prompt_file" "$backup_dir/.bash_prompt"
    fi
    answer=y
    if has_local_prompt; then
        printf 'Existing local prompt found. Change prompt colors? [y/N] ' >/dev/tty
        read -r answer </dev/tty || return 1
    fi
    if [[ $answer == [yY] || $answer == [yY][eE][sS] ]]; then
        print_color_menu
        select_color Username; user_sgr=$SELECTED_SGR
        select_color Hostname; host_sgr=$SELECTED_SGR
        username=$(id -un); hostname=$(hostname -s); directory=$(basename -- "$PWD")
        printf 'Prompt preview: \033[%sm%s\033[0m@\033[%sm%s\033[0m:%s$ command\n' \
            "$user_sgr" "$username" "$host_sgr" "$hostname" "$directory" >/dev/tty
        prompt_definition="PS1='\\[\\e[${user_sgr}m\\]\\u\\[\\e[0m\\]@\\[\\e[${host_sgr}m\\]\\h\\[\\e[0m\\]:\\W\\$ '"
        write_local_block prompt "$prompt_definition"
    fi

    current_history=$(local_setting history-policy)
    legacy_history="${XDG_CONFIG_HOME:-$HOME/.config}/dotbash-files/history"
    if [[ -z $current_history && -r $legacy_history ]]; then
        IFS= read -r current_history < "$legacy_history" || :
    fi
    if ! valid_history "$current_history"; then
        current_history=''
    fi
    answer=y
    if [[ -n $current_history ]]; then
        printf 'Existing history setting: %s. Change it? [y/N] ' "$current_history" >/dev/tty
        read -r answer </dev/tty || return 1
    fi
    history_choice=$current_history
    if [[ $answer == [yY] || $answer == [yY][eE][sS] ]]; then
        printf '\nBash history:\n  -1       session only; discard history on exit\n   0       never keep command history\n  100-32768 persist that many commands\n' >/dev/tty
        while true; do
            printf 'History setting [%s]: ' "${current_history:-1000}" >/dev/tty
            read -r history_choice </dev/tty || return 1
            history_choice=${history_choice:-${current_history:-1000}}
            valid_history "$history_choice" && break
            echo 'Use -1, 0, or a number from 100 through 32768.' >/dev/tty
        done
    fi
    if [[ $answer == [yY] || $answer == [yY][eE][sS] || -z $(local_setting history-policy) ]]; then
        case "$history_choice" in
            -1) content=$'# dotbash-history-policy: -1\nhistory -c\nHISTSIZE=32768\nHISTFILESIZE=0\nHISTFILE=/dev/null' ;;
            0) content=$'# dotbash-history-policy: 0\nhistory -c\nHISTSIZE=0\nHISTFILESIZE=0\nHISTFILE=/dev/null' ;;
            *) printf -v content '# dotbash-history-policy: %s\nHISTSIZE=%s\nHISTFILESIZE=%s\nHISTFILE="$HOME/.bash_history"' "$history_choice" "$history_choice" "$history_choice" ;;
        esac
        write_local_block history "$content"
    fi
    if [[ -f $legacy_history ]]; then
        command mv -- "$legacy_history" "$backup_dir/history-policy"
    fi
    setup_gitconfig
}

# Leading zeroes are rejected to avoid Bash's octal arithmetic interpretation.
valid_history() {
    [[ $1 == -1 || $1 == 0 ]] ||
        { [[ $1 =~ ^[1-9][0-9]{2,4}$ ]] && (( $1 >= 100 && $1 <= 32768 )); }
}

has_local_prompt() {
    grep -Eq '(^|[[:space:];])(export[[:space:]]+)?(PS1|PROMPT_COMMAND)=' "$HOME/.bash_local"
}

install_user() {
    local stamp backup_dir target source command_name i answer
    local bin_dir state_dir manifest legacy_functions_dir
    local -a sources targets current_commands stale_candidates

    echo 'dotbash-files installer'
    printf 'Install/update Bash configuration and local settings? [y/N] ' >/dev/tty
    read -r answer </dev/tty || exit 1
    [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || {
        echo 'Cancelled.'; exit 1;
    }

    stamp=$(date '+%Y%m%d-%H%M%S')
    backup_dir=$(mktemp -d "$HOME/.bash-backup-$stamp.XXXXXXXX") || exit 1
    chmod 0700 -- "$backup_dir"

    setup_local

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
    stale_candidates=(git-clean test.sh dotbash-doctor)

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

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    if (( EUID == 0 )); then
        install_root
    else
        install_user
    fi
fi
