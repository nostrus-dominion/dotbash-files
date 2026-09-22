# dotbash-files

*One set of shortcuts. Several machines. Distinct prompt colors so you know which server you're about to bother.*

The shared Bash setup lives at the repository root. Host files contain only the prompt and settings specific to that machine. CORSAIR's ComfyUI and `yt-dlp` commands live in optional Bash modules.

```text
dotbash-files/
├── .bash_common
├── .bash_aliases
├── .bash_functions
├── .bash_functions.d/
│   ├── comfy.bash
│   └── ytdl.bash
├── hosts/
│   ├── corsair.bashrc
│   ├── jumpbox.bashrc
│   ├── media-server.bashrc
│   ├── seedbox.bashrc
│   └── thevault.bashrc
├── root.bashrc
├── install.sh
└── README.md
```

`.bash_common` holds settings that used to appear in every host file: history, window-size updates, `lesspipe`, color support, standard `ls` aliases, loading `.bash_aliases` and `.bash_functions`, and programmable completion. Each host's `.bashrc` sources it, then sets its prompt and any host-specific commands. The root prompt is separate and is not installed by `install.sh`.

## Commands

| Command | What it does |
| --- | --- |
| `please` | Displays the previous history command and asks before running it with `sudo bash` |
| `mkcd NAME` | Creates and enters a directory |
| `extract ARCHIVE` | Extracts common archive formats, including paths with spaces |
| `freeport PORT` | Lists processes using a port and sends TERM |
| `default-interface` | Finds the default IPv4 network interface |
| `iftop`, `tcpdump`, `vnstat`, `ethtool`, `dnstop` | Use that interface unless you specify another |
| `ports` | Displays listening TCP/UDP sockets via `ss` |
| `pyact` | Finds a `venv*/bin/activate` and asks before activating |
| `comfy`, `comfy-backup`, `ytdl` | Optional CORSAIR-specific commands |
| `reset-master-branch` | Guarded reset and force-with-lease push to `origin/master` |

Read what `please` displays before approving: shell substitutions and operators in your previous command will run with sudo. `comfy` and `ytdl` assume CORSAIR's paths and software are installed.

## Install

Clone or extract the repository somewhere you intend to keep it. `install.sh` creates links into that directory, so moving or deleting the directory later will break those links. Run the installer **as your own user**, not with sudo:

```bash
bash install.sh corsair
```

Supported names: `corsair`, `jumpbox`, `media-server`, `seedbox`, and `thevault`. With no argument the installer uses your short hostname if it matches one of these names. It shows the chosen host and asks for confirmation. Existing `~/.bashrc`, `~/.bash_common`, `~/.bash_aliases`, `~/.bash_functions`, and `~/.bash_functions.d` entries are moved into a timestamped `~/.bash-backup-*` directory before links are installed. Open a new Bash session afterward.

To restore your previous configuration, move the backed-up files from that directory back into your home directory after removing the links. A backup folder is created even on a fresh account, where it may be empty.

The installer links the optional module directory on every host. Those functions load but only work where their dependencies and machine-specific paths exist. If you want a command available on one host only, install the shared files manually and omit the module link there.

## Validate

```bash
bash -n .bash_common .bash_aliases .bash_functions .bash_functions.d/*.bash hosts/*.bashrc root.bashrc install.sh
```

These are personal utilities. Dependencies include `ip`, `ss`, `lsof`, `git`, `curl`, `jq`, `yt-dlp`, `ffmpeg`, and `7z` for particular commands.
