#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$repo_dir"

echo 'Checking Bash syntax...'
bash -n .bashrc .bash_common .bash_exports .bash_aliases .bash_functions install.sh

for file in bin/*; do
    [[ -f $file ]] || continue
    bash -n "$file"

    grep -q '^# description:' "$file" || {
        printf 'Missing description metadata: %s\n' "$file" >&2
        exit 1
    }

    grep -q '^# usage:' "$file" || {
        printf 'Missing usage metadata: %s\n' "$file" >&2
        exit 1
    }
done

echo 'Bash syntax: OK'

if command -v shellcheck >/dev/null 2>&1; then
    echo 'Running ShellCheck...'
    shellcheck -x -e SC1090,SC1091,SC2139         .bashrc .bash_common .bash_exports .bash_aliases .bash_functions install.sh bin/*
    echo 'ShellCheck: OK'
else
    echo 'ShellCheck: not installed; skipped.'
fi
