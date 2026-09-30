# dotbash-files

*One Bash setup, several machines, and fewer mystery commands six months from now.*

The repository separates environment, shell behavior, shell-local helpers, and standalone commands:

```text
dotbash-files/
├── bin/
│   ├── getcerts
│   ├── comfy
│   ├── digga
│   ├── git-check-clean
│   ├── git-reset-repo
│   ├── my-commands
│   ├── ports
│   ├── repo
│   ├── server
│   ├── test.sh
│   └── ytdl
├── .bashrc
├── .bash_common
├── .bash_exports
├── .bash_aliases
├── .bash_functions
├── install.sh
└── README.md
```

## What goes where

- `.bashrc` — generic interactive entry point.
- `.bash_exports` — exported environment variables and PATH setup.
- `.bash_common` — history, colors, completion, NVM initialization, loading shared Bash files, and finally optional `~/.bash_local` overrides.
- `.bash_aliases` — simple command substitutions.
- `.bash_functions` — commands that must affect the current shell, such as changing directory, activating a virtual environment, or reading Bash history.
- `bin/` — standalone programs installed into `~/.local/bin`.

If a command does not need to modify the current Bash process, it should normally live in `bin/`.

## Prompt

Normal-user installs generate `~/.bash_prompt`. On first install, the installer asks for separate username and hostname colors. On later runs, an existing prompt scheme is preserved by default; the color menu is shown only when you explicitly choose to change it. The prompt layout stays fixed:

```text
user@host:dir$ command
```

Only the username and hostname are colored. The separator, current directory, dollar sign, trailing space, and command text use the terminal's normal color.

The installer includes named ANSI colors plus a custom ANSI-256 option.

## Environment and NVM

Shared exports live in `.bash_exports`, including the editor settings, `~/.local/bin` PATH setup, and:

```bash
export NVM_DIR="$HOME/.nvm"
```

`.bash_common` loads NVM only when its files exist:

```bash
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
fi

if [[ -s "$NVM_DIR/bash_completion" ]]; then
    source "$NVM_DIR/bash_completion"
fi
```

Machines without NVM simply skip those files.


## Local overrides

`~/.bash_local` is a user-owned file for machine-specific, private, or experimental configuration. The installer creates an empty `~/.bash_local` with mode `0600` if it does not exist, then never overwrites, links, or replaces it.

Examples:

```bash
export SOME_PRIVATE_VAR="..."
alias media='ssh media-server'
export PATH="$HOME/special-tools/bin:$PATH"
```

Because it is sourced last by `.bash_common`, local settings can intentionally override the shared configuration.

## Command reference

Run:

```bash
my-commands
```

The reference builds itself at runtime. It reads aliases from `~/.bash_aliases`, function descriptions from comments in `~/.bash_functions`, and standalone commands directly from this repository's `bin/` directory. It does **not** scan every executable in `~/.local/bin`, so commands installed by unrelated applications are not mixed into the list.

For shell functions, put a useful comment immediately above the function:

```bash
# Create a directory and enter it.
mkcd() {
    ...
}
```

Standalone commands use two lightweight metadata headers:

```bash
#!/usr/bin/env bash
# description: Check whether the current Git working tree is clean.
# usage: git check-clean
```

Adding a new alias, documented function, or `bin/` command does not require editing `my-commands`.

## Install

For a normal user:

```bash
bash install.sh
```

The installer asks for username and hostname colors, shows a prompt preview, and then installs the shared configuration.

It:

1. backs up existing Bash files into a timestamped `~/.bash-backup-*` directory;
2. links `.bashrc`, `.bash_common`, `.bash_exports`, `.bash_aliases`, and `.bash_functions` back to this repository;
3. preserves an existing `~/.bash_prompt` unless you explicitly choose to change its colors; otherwise it generates the prompt;
4. creates `~/.bash_local` once if it is missing and leaves it user-owned thereafter;
5. symlinks repo-owned `bin/` commands into `~/.local/bin`, so a `git pull` updates them immediately;
6. records those command names in `~/.local/share/dotbash-files/bin-manifest`;
7. moves commands that disappeared from the repo into the backup directory on the next install.

The old `~/.bash_functions.d` path is retired during migration and moved into the same backup directory if it still exists. `.bash_common` also clears legacy in-memory `comfy`, `comfy-backup`, `ytdl`, `ports`, `port`, and `freeport` function definitions so a reload immediately exposes the standalone commands in `~/.local/bin`. The pre-manifest `git-clean` command is also treated as a known stale command.

Open a new Bash terminal after installation.

### Root prompt

Run the same installer as root:

```bash
sudo bash install.sh
```

When `EUID == 0`, the installer performs only the root prompt installation. It does not install aliases, functions, exports, standalone commands, or the normal-user prompt.

The root prompt is defined directly in `install.sh` and written to the bottom of `/root/.bashrc` inside a managed block:

```bash
# >>> dotbash-files root prompt >>>
export PS1='...'
# <<< dotbash-files root prompt <<<
```

Running the root installer again replaces that managed block instead of appending duplicates. The previous `/root/.bashrc` is backed up first.

## Shell helpers

A few conveniences intentionally remain shell functions or aliases rather than standalone commands:

- `tmpd [name]` — create a temporary directory and immediately enter it.
- `man` — wraps the system man command with colorized headings and emphasis.
- `tre` — compact, colorized tree view with hidden files, common dependency directories excluded, and pager output.

## Standalone commands

Current repo-owned programs include:

- `comfy` — manage the ComfyUI systemd service; `comfy --backup` creates the rebuild backup.
- `ytdl` — the standard yt-dlp wrapper.
- `git check-clean` — show repository status and return nonzero when the working tree has changes.
- `git reset-repo` — guarded reset of the default branch to `upstream`, followed by a force-with-lease push to `origin`.
- `my-commands` — show the generated command reference.
- `ports` — list listeners, inspect one port, or gracefully free a port with `ports --free PORT`; the script stays unprivileged and requests sudo only for the exact inspection/termination operation that needs it.
- `server` — serve the current directory in the background with generated Basic Auth credentials by default; use `server --unsecure` to disable authentication, `server --stop` to stop the managed server, and expect automatic shutdown after 30 minutes without an HTTP request.
- `getcerts` — inspect a host's TLS certificate, SANs, issuer, fingerprint, validity, and days until expiration.
- `digga` — concise DNS lookup wrapper around `dig`.
- `repo` — open the current Git repository, subdirectory, or file in its remote web interface.

Git discovers executables named `git-<name>` on PATH, which is why `git-check-clean` is invoked as `git check-clean`.

## Testing

Run:

```bash
bin/test.sh
```

The test command syntax-checks the shared Bash files and every command in `bin/`, verifies command metadata, and runs ShellCheck when it is installed.

## Validation

The Bash configuration can be syntax-checked with:

```bash
bash -n .bashrc .bash_common .bash_exports .bash_aliases .bash_functions install.sh

for file in bin/*; do
    [[ $(head -n 1 "$file") == '#!/usr/bin/env bash' ]] && bash -n "$file"
done
```

Individual utilities have their own dependencies. Common ones include `ip`, `ss`, `curl`, `jq`, `dig`, `openssl`, `python3`, `tree`, `7z`, `yt-dlp`, `ffmpeg`, `rsync`, and `zstd`.
