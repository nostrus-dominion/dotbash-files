#!/usr/bin/env bash
# description: Validate dotbash-files scripts, metadata, and ShellCheck when available.
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

bash_files=("${shared_files[@]}")
ruby_files=()

echo 'Checking script syntax...'
bash -n "${shared_files[@]}"

for file in bin/*; do
    [[ -f $file ]] || continue

    grep -q '^# description:' "$file" || {
        printf 'Missing description metadata: %s\n' "$file" >&2
        exit 1
    }

    grep -q '^# usage:' "$file" || {
        printf 'Missing usage metadata: %s\n' "$file" >&2
        exit 1
    }

    case "$(head -n 1 "$file")" in
        '#!/usr/bin/env bash'|'#!/bin/bash')
            bash -n "$file"
            bash_files+=("$file")
            ;;
        '#!/usr/bin/env ruby'|'#!/usr/bin/ruby')
            ruby_files+=("$file")
            ;;
    esac
done

echo 'Bash syntax and command metadata: OK'

if (( ${#ruby_files[@]} > 0 )); then
    if command -v ruby >/dev/null 2>&1; then
        for file in "${ruby_files[@]}"; do
            ruby -c "$file" >/dev/null
        done
        echo 'Ruby syntax: OK'
    else
        echo 'Ruby: not installed; Ruby syntax checks skipped.'
    fi
fi

if command -v shellcheck >/dev/null 2>&1; then
    echo 'Running ShellCheck...'
    shellcheck -x -e SC1090,SC1091,SC2139 "${bash_files[@]}"
    echo 'ShellCheck: OK'
else
    echo 'ShellCheck: not installed; skipped.'
fi
