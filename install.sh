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

sources=("$repo_dir/hosts/$host.bashrc" "$repo_dir/.bash_common" "$repo_dir/.bash_aliases" "$repo_dir/.bash_functions" "$repo_dir/.bash_functions.d")
targets=("$HOME/.bashrc" "$HOME/.bash_common" "$HOME/.bash_aliases" "$HOME/.bash_functions" "$HOME/.bash_functions.d")

for i in "${!targets[@]}"; do
    target=${targets[i]}
    if [[ -e $target || -L $target ]]; then
        mv -- "$target" "$backup_dir/$(basename -- "$target")"
    fi
    ln -s -- "${sources[i]}" "$target"
done

printf 'Installed %s. Previous files (if any): %s\nOpen a new Bash terminal to load the settings.\n' "$host" "$backup_dir"
