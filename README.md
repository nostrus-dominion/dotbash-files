# dotbash-files

*One Bash setup, several machines, and fewer mystery commands six months from now.*

The repository separates environment, shell behavior, shell-local helpers, and standalone commands:

```text
dotbash-files/
├── bin/
│   ├── comfy
│   ├── git-check-clean
│   ├── git-reset-repo
│   ├── my-commands
│   └── ytdl
├── .bashrc
├── .bash_common
├── .bash_exports
├── .bash_aliases
├── .bash_functions
├── root.bashrc
├── install.sh
└── README.md
```

## What goes where

- `.bashrc` — generic interactive entry point.
- `.bash_exports` — exported environment variables and PATH setup.
- `.bash_common` — history, colors, completion, NVM initialization, and loading shared Bash files.
- `.bash_aliases` — simple command substitutions.
- `.bash_functions` — commands that must affect the current shell, such as changing directory, activating a virtual environment, or reading Bash history.
- `bin/` — standalone programs installed into `~/.local/bin`.
- `root.bashrc` — the root-only prompt definition used by the installer.

If a command does not need to modify the current Bash process, it should normally live in `bin/`.

## Prompt

Normal-user installs generate `~/.bash_prompt`. The installer asks for separate username and hostname colors and keeps the prompt layout fixed:

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
3. generates `~/.bash_prompt`;
4. copies repo-owned `bin/` commands into `~/.local/bin`;
5. records those command names in `~/.local/share/dotbash-files/bin-manifest`;
6. moves commands that disappeared from the repo into the backup directory on the next install.

The old `~/.bash_functions.d` path is retired during migration and moved into the same backup directory if it still exists. The pre-manifest `git-clean` command is also treated as a known stale command.

Open a new Bash terminal after installation.

### Root prompt

Run the same installer as root:

```bash
sudo bash install.sh
```

When `EUID == 0`, the installer performs only the root prompt installation. It does not install aliases, functions, exports, standalone commands, or the normal-user prompt.

The root prompt from `root.bashrc` is written to the bottom of `/root/.bashrc` inside a managed block:

```bash
# >>> dotbash-files root prompt >>>
export PS1='...'
# <<< dotbash-files root prompt <<<
```

Running the root installer again replaces that managed block instead of appending duplicates. The previous `/root/.bashrc` is backed up first.

## Standalone commands

Current repo-owned programs include:

- `comfy` — manage the ComfyUI systemd service; `comfy --backup` creates the rebuild backup.
- `ytdl` — the standard yt-dlp wrapper.
- `git check-clean` — show repository status and return nonzero when the working tree has changes.
- `git reset-repo` — guarded reset of the default branch to `upstream`, followed by a force-with-lease push to `origin`.
- `my-commands` — show the generated command reference.

Git discovers executables named `git-<name>` on PATH, which is why `git-check-clean` is invoked as `git check-clean`.

## Validation

The Bash configuration can be syntax-checked with:

```bash
bash -n .bashrc .bash_common .bash_exports .bash_aliases .bash_functions root.bashrc install.sh

for file in bin/*; do
    [[ $(head -n 1 "$file") == '#!/usr/bin/env bash' ]] && bash -n "$file"
done
```

Individual utilities have their own dependencies. Common ones include `ip`, `ss`, `lsof`, `curl`, `jq`, `7z`, `yt-dlp`, `ffmpeg`, `rsync`, and `zstd`.
