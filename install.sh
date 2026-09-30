#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
host=${1:-$(hostname -s | tr '[:upper:]' '[:lower:]')}

if [[ $# -gt 1 || $host == -h || $host == --help || ! -f $repo_dir/hosts/$host.bashrc ]]; then
    printf 'Usage: %s [corsair|jumpbox|media-server|seedbox|thevault]\n' "$0" >&2
    exit 2
fi

printf 'Install Bash settings for %s from %s into %s? [y/N] ' "$host" "$repo_dir" "$HOME"
read -r answer </dev/tty || exit 1
[[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { echo 'Cancelled.'; exit 1; }

stamp=$(date '+%Y%m%d-%H%M%S')
backup_dir="$HOME/.bash-backup-$stamp"
if [[ -e $backup_dir ]]; then
    printf 'Backup directory already exists: %s\n' "$backup_dir" >&2
    exit 1
fi
mkdir -- "$backup_dir"

sources=("$repo_dir/hosts/$host.bashrc" "$repo_dir/.bash_common" "$repo_dir/.bash_aliases" "$repo_dir/.bash_functions")
targets=("$HOME/.bashrc" "$HOME/.bash_common" "$HOME/.bash_aliases" "$HOME/.bash_functions")

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

# Install standalone commands and remember exactly which names this repo owns.
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
    local command_name

    for command_name in "${current_commands[@]}"; do
        [[ $candidate == "$command_name" ]] && return 0
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

        install -m 0755 -- "$source" "$target"
    done
fi

printf '%s\n' "${current_commands[@]}" > "$manifest"

printf 'Installed %s. Previous files (if any): %s\nOpen a new Bash terminal to load the settings.\n' "$host" "$backup_dir"
