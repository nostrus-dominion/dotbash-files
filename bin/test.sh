#!/usr/bin/env bash
# description: Validate dotbash-files Bash syntax, metadata, and ShellCheck when available.
# usage: test.sh

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo_dir"

shared_files=(
    .bashrc
    .bash_common
    .bash_exports
    .bash_aliases
    .bash_functions
    install.sh
)

echo 'Checking Bash syntax...'
bash -n "${shared_files[@]}"

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

echo 'Bash syntax and command metadata: OK'

if command -v shellcheck >/dev/null 2>&1; then
    echo 'Running ShellCheck...'
    shellcheck -x -e SC1090,SC1091,SC2139 "${shared_files[@]}" bin/*
    echo 'ShellCheck: OK'
else
    echo 'ShellCheck: not installed; skipped.'
fi
