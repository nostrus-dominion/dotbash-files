# dotbash-files

*One Bash, several machines, and fewer mystery commands six months from now.*

The repository separates environment, shell behavior, shell-local helpers, and standalone commands:

```text
dotbash-files/
├── bin/
│   ├── battery
│   ├── getcerts
│   ├── comfy
│   ├── digga
│   ├── git-check-clean
│   ├── git-reset-repo
│   ├── git-wtf
│   ├── my-commands
│   ├── ports
│   ├── repo
│   ├── server
│   ├── dr-bash
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
- `.bash_aliases` — simple command substitutions.
- `.bash_common` — shared defaults, colors, completion, NVM initialization, and loading shared Bash files.
- `.bash_exports` — exported environment variables and PATH setup.
- `.bash_functions` — commands that must affect the current shell, such as changing directory, activating a virtual environment, or reading Bash history.
- `.bash_local` — private prompt, history policy, shell Git identity overrides, and final machine-specific settings. This file lives outside the repository and is sourced last by `.bashrc`.
- `bin/` — standalone programs installed into `~/.local/bin`.

If a command does not need to modify the current Bash process, it should normally live in `bin/`.

## Prompt

Normal-user installs store the prompt in `~/.bash_local`. On first install, the installer asks for separate username and hostname colors. On later runs, an existing prompt scheme is preserved by default; the color menu is shown only when you explicitly choose to change it. The prompt layout stays fixed:

```text
user@host:dir$ command
```

Only the username and hostname are colored. The separator, current directory, dollar sign, trailing space, and command text use the terminal's normal color.

The installer includes named ANSI colors plus a custom ANSI-256 option.

## Bash history

The installer stores the selected history policy as Bash assignments in `~/.bash_local`. Existing settings are preserved on later installer runs unless you explicitly choose to change them.

Accepted values:

- `-1` — keep history only for the current shell session and discard it on exit.
- `0` — do not keep command history.
- `100` through `32768` — persist exactly that many commands.

The default for a new install is `1000`.

## Git identity

Git cannot read Bash code. The installer retires `~/.local/gitconfig` and migrates its settings into native global Git configuration (`~/.gitconfig`, or Git's existing XDG global config). Native configuration keeps editors and GUI clients working.

The selected identity also lives in a small block in `~/.bash_local`:

```bash
export GIT_AUTHOR_NAME='Your Name'
export GIT_AUTHOR_EMAIL='you@example.com'
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
```

These environment variables override Git identity in shells, including repository-local identity settings. Remove/unset the exports if you prefer Git's native per-repository identity selection. Editing this block changes shell identity after `rebash`; changes for GUI clients require updating `git config --global user.name` and `user.email` too. No Git configuration is written during shell startup.

The installer asks before changing an existing identity and preserves custom credential helpers. On a fresh install, it defaults to `cache` on Linux or `osxkeychain` on macOS.

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

`~/.bash_local` holds your machine settings and is loaded **last**, after all shared configuration. It is a regular file with mode `0600`, never a link into the repository.

The installer puts prompt, history, and shell Git identity in labeled blocks. It only replaces a setting's block when you choose to change that setting. All custom code outside the blocks remains intact and appears afterward, so your overrides win.

Examples:

```bash
export EDITOR=vim
export VISUAL=vim
export PATH="$HOME/special-tools/bin:$PATH"
export SOME_PRIVATE_VAR="..."
alias media='ssh media-server'
PS1='my custom prompt> '
HISTCONTROL=ignoreboth:erasedups
shopt -s autocd
# Functions, completion hooks, proxy settings and machine-specific variables
# can also go here. Bash code in this file executes every time you reload it.
```

Do not commit credentials or private configuration to the shared repository. On migration, the old prompt and history settings are imported, the old Git include is migrated into native Git configuration, and the retired files are backed up. Existing local overrides still win. Previously configured NVM is initialized by shared configuration before local overrides; changing its location requires initializing NVM in the local file too.

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

1. backs up existing files into a private `~/.bash-backup-*` directory;
2. links `.bashrc`, `.bash_common`, `.bash_exports`, `.bash_aliases`, and `.bash_functions` back to this repository;
3. creates or migrates `~/.bash_local`, preserving its custom code;
4. asks before changing an existing prompt, history policy, or Git identity (default is keep);
5. migrates the separate `.bash_prompt`, history-policy file, and `.local/gitconfig`, backing them up before retiring them;
6. symlinks repo-owned `bin/` commands into `~/.local/bin`, so a `git pull` updates them immediately;
7. records those command names in `~/.local/share/dotbash-files/bin-manifest`;
8. moves commands removed from the repo, including the retired `test.sh`, into the backup directory on the next install.

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
- `zipit [date]` — bundle the current directory into an uncompressed `zipit.zip` for fast, easy movement; an optional date expression keeps only entries modified on or before that cutoff.
- `store [date]` — preserve the current Unix filesystem tree in an uncompressed `store.tar`; an optional date expression keeps only entries modified on or before that cutoff.
- `targz <file-or-directory>` — create a portable compressed `.tar.gz`, using `pigz` when available and falling back to `gzip`.
- `man` — wraps the system man command with colorized headings and emphasis.
- `tre` — compact, colorized tree view with hidden files, common dependency directories excluded, and pager output.
- `pubkey` — copy the preferred SSH public key (`id_ed25519.pub`, then `id_rsa.pub`) to the desktop clipboard using `wl-copy`, `xclip`, or `pbcopy`; if no clipboard command is available, print the key instead.

## Standalone commands

Current repo-owned programs include:

- `dr-bash` — one self-contained command that automatically runs repository validation, machine diagnostics and isolated behavior checks.
- `battery` — show a compact battery/AC indicator on macOS and Linux; prints nothing when no battery is present.
- `comfy` — manage the ComfyUI systemd service; `comfy --backup` creates the rebuild backup.
- `ytdl` — the standard yt-dlp wrapper.
- `git check-clean` — show repository status and return nonzero when the working tree has changes.
- `git reset-repo` — guarded reset of the default branch to `upstream`, followed by a force-with-lease push to `origin`.
- `git wtf` — Ruby-based summary of how local and remote branches relate, including ahead/behind state and optional integration/feature branch relationships.
- `my-commands` — show the generated command reference.
- `ports` — list listeners, inspect one port, or gracefully free a port with `ports --free PORT`; the script stays unprivileged and requests sudo only for the exact inspection/termination operation that needs it.
- `server` — serve the current directory in the background with generated Basic Auth credentials by default; use `server --unsecure` to disable authentication and `server --stop` to stop the managed server. It automatically shuts down after the configured idle timeout (30 minutes by default) without an HTTP request. Runtime state uses `XDG_RUNTIME_DIR`; logs use `XDG_STATE_HOME` (`~/.local/state/dotbash-files/logs/server.log` by default).
- `getcerts` — inspect a host's TLS certificate, SANs, issuer, fingerprint, validity, and days until expiration.
- `digga` — concise DNS lookup wrapper around `dig`.
- `repo` — open the current Git repository, subdirectory, or file in its remote web interface.

Git discovers executables named `git-<name>` on PATH, which is why `git-check-clean` is invoked as `git check-clean`.

## Dr. Bash and validation

```bash
dr-bash           # all diagnostics and behavior checks, automatically
dr-bash --check   # optional: repository validation only
dr-bash --no-color # optional: disable terminal color
```

Output uses a MOTD-style `DR. BASH` banner with `// DOT FILES DIAGNOSTIC TOOL //`, host/time metadata, grouped diagnostics, a compact dependency grid, concise runtime versions, and a final health summary. Green means passed, yellow means warnings, and red means failed checks. The layout adapts to terminal width. Color is automatic for terminals, disabled for pipes/logs and `NO_COLOR`, and configurable with `--color=auto|always|never` or `--no-color`.

All validation code lives inside `bin/dr-bash`; there is no separate tests directory or supporting test script. Before installation, run `bin/dr-bash` from the checkout. The installed symlink works from any directory. It replaces `bin/test.sh` and the former `dotbash-doctor` command; rerun `install.sh` to install `dr-bash` and back up the old installed commands.

Checks include each shared Bash file separately, command metadata and executable modes, Ruby syntax when Ruby is installed, and ShellCheck when available (with Bash selected explicitly for sourced files). Machine diagnostics report missing tools with the commands that need them, broken or outdated links, PATH shadowing, runtime versions, local-file syntax/permissions, and leftover legacy settings. Optional missing tools are warnings; failures exit `1` and invalid arguments exit `2`. The doctor never sources your private local code or changes your real settings. Its embedded archive checks use temporary files; installer checks use a temporary home. These fixtures are removed afterward. A standalone process cannot inspect aliases/functions already loaded in its parent shell; use `type -a server` (or another command) there. The doctor flags common aliases visible in the local file.

A plain `dr-bash` automatically runs the embedded behavior checks, which exercise fresh and repeated installation in a temporary home, legacy migration, final prompt overrides, all history policies, invocation through a symlink, and archive content/metadata/date filters/failure cleanup. Checks run in independent groups. Archive preflight probes the required TAR, date and find operations directly instead of matching version banners, and names the missing capability when it skips. Missing tools produce explicit skipped-check warnings; archive checks require GNU tar/find/date, Python 3 and gzip/pigz, and installer checks require Python 3 and Git. Ruby and ShellCheck remain optional. A “ShellCheck not found on PATH” warning means the external linter is unavailable; Bash syntax and the other checks still run. Install ShellCheck with your package manager (`sudo apt install shellcheck` on Debian/Ubuntu, or `brew install shellcheck` on macOS), then rerun `dr-bash` to include lint automatically.

## Archive guarantees

All three helpers run in subshells. They leave your current directory, shell options and traps alone, reject existing output files (including dangling symlinks), remove temporary/partial outputs on failure, and publish a completed archive without overwriting another file.

- `zipit [date]` creates `zipit.zip` with **zero compression** using Python 3's standard ZIP library. Dotfiles, empty directories and filenames containing spaces/newlines are supported. Date filtering selects individual entries, so an older directory does not pull in newer descendants. Symlinks are stored as links, but ZIP readers differ in how they restore Unix attributes. Special files require `store`.
- `store [date]` creates uncompressed `store.tar` with GNU tar (`gtar` on macOS). It records permissions, numeric ownership, symlinks, hard links, directory metadata, sparse files, ACLs and extended attributes. GNU find/date are needed for date expressions. This is a filesystem archive, not a live atomic snapshot; changing files can cause failure, and privileged ownership/attributes may require root to read or restore.
- `targz <file-or-directory>` creates a standard gzip tarball beside its input, using `pigz` or `gzip`. `targz .` writes beside the current directory, so the archive cannot include itself. It includes dotfiles and uses ordinary portable tar metadata; use `store` for the richer GNU metadata guarantees. Both tar and compressor failures are checked.

To restore a `store` archive with GNU tar:

```bash
mkdir restored
tar --acls --xattrs --xattrs-include='*' -xpf store.tar -C restored
```

Use appropriate privileges when restoring numeric ownership or protected attributes. Extraction cannot recreate metadata that the source filesystem or your privileges prevented the archive from reading.
