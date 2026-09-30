# dotbash-files

*One Bash setup, several machines, and fewer mystery commands six months from now.*

The repository separates interactive shell behavior from standalone commands:

```text
dotbash-files/
├── bin/
│   ├── comfy
│   ├── git-check-clean
│   ├── git-reset-repo
│   ├── my-commands
│   └── ytdl
├── hosts/
│   ├── corsair.bashrc
│   ├── jumpbox.bashrc
│   ├── media-server.bashrc
│   ├── seedbox.bashrc
│   └── thevault.bashrc
├── .bash_common
├── .bash_aliases
├── .bash_functions
├── root.bashrc
├── install.sh
└── README.md
```

## What goes where

- `.bash_common` — shared interactive Bash configuration, PATH setup, colors, completion, and loaders.
- `.bash_aliases` — simple command substitutions.
- `.bash_functions` — commands that need the current shell, such as changing directory, activating a virtual environment, or reading Bash history.
- `bin/` — standalone programs. These are installed into `~/.local/bin`.
- `hosts/` — host-specific prompts and settings.

If a command does not need to modify the current Bash process, it should normally live in `bin/`.

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

## Standalone commands

Current repo-owned programs include:

- `comfy` — manage the ComfyUI systemd service; `comfy --backup` creates the rebuild backup.
- `ytdl` — the standard yt-dlp wrapper.
- `git check-clean` — show repository status and return nonzero when the working tree has changes.
- `git reset-repo` — guarded reset of the default branch to `upstream`, followed by a force-with-lease push to `origin`.
- `my-commands` — show the generated command reference.

Git discovers executables named `git-<name>` on PATH, which is why `git-check-clean` is invoked as `git check-clean`.

## Install

Clone the repository somewhere permanent, then run the installer as your normal user:

```bash
bash install.sh corsair
```

Supported hosts are `corsair`, `jumpbox`, `media-server`, `seedbox`, and `thevault`. With no argument, the installer uses the machine's short hostname when it matches one of those names.

The installer:

1. backs up the existing Bash files into a timestamped `~/.bash-backup-*` directory;
2. links `.bashrc`, `.bash_common`, `.bash_aliases`, and `.bash_functions` back to this repository;
3. copies repo-owned `bin/` commands into `~/.local/bin` with executable permissions;
4. records those command names in `~/.local/share/dotbash-files/bin-manifest`;
5. moves commands that disappeared from the repo into the backup directory on the next install.

The old `~/.bash_functions.d` path is retired during migration and moved into the same backup directory if it still exists. The pre-manifest `git-clean` command is also treated as a known stale command.

Open a new Bash terminal after installation.

## Validation

The Bash configuration and standalone Bash commands can be syntax-checked with:

```bash
bash -n .bash_common .bash_aliases .bash_functions hosts/*.bashrc root.bashrc install.sh
for file in bin/*; do
    [[ $(head -n 1 "$file") == '#!/usr/bin/env bash' ]] && bash -n "$file"
done
```

Individual utilities have their own dependencies. Common ones include `ip`, `ss`, `lsof`, `curl`, `jq`, `7z`, `yt-dlp`, `ffmpeg`, `rsync`, and `zstd`.
