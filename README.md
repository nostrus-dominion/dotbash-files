# dotbash-files

*One set of shortcuts. Several machines. Distinct prompt colors so you know which server you're about to bother.*

This is my Bash setup: shared aliases and functions, plus a `.bashrc` for each host. CORSAIR also has ComfyUI and `yt-dlp` helpers in separate modules. The configuration reflects my machines and paths, so read it before installing it on yours.

| File | Job |
| --- | --- |
| `.bash_aliases` | Shared navigation, system, Python, and networking shortcuts |
| `.bash_functions` | Shared helpers and a loader for optional modules |
| `.bash_functions.d/comfy.bash` | `comfy` service controls and `comfy-backup` |
| `.bash_functions.d/ytdl.bash` | `ytdl` wrapper with download defaults |
| `corsair.bashrc` | CORSAIR prompt and shell settings |
| `jumpbox.bashrc`, `media-server.bashrc`, `seedbox.bashrc`, `thevault.bashrc` | Host prompts and local settings |
| `root.bashrc` | Distinct root prompt |

## Commands I actually use

| Command | What it does |
| --- | --- |
| `please` | Shows the previous history command, asks for approval, then runs it under `sudo bash` |
| `mkcd NAME` | Creates a directory and enters it |
| `extract ARCHIVE` | Extracts a supported archive, including filenames with spaces |
| `freeport PORT` | Displays processes using a port and sends TERM; does not force kill |
| `default-interface` | Prints the interface used for the default IPv4 route |
| `iftop`, `tcpdump`, `vnstat`, `ethtool`, `dnstop` | Use that interface by default; pass an interface to override |
| `ports` | Lists listening TCP/UDP sockets with `ss` |
| `pyact` | Finds a local `venv*/bin/activate` and asks before activating |
| `comfy`, `comfy-backup`, `ytdl` | Optional CORSAIR modules |
| `reset-master-branch` | Guarded reset to `upstream/master` and force-with-lease push to `origin/master` |

The `please` command runs the displayed history entry as Bash under sudo, including any operators or substitutions it contains. Read the command before approving it.

## Install

```bash
git clone https://github.com/nostrus-dominion/dotbash-files.git
cd dotbash-files
cp -a ~/.bashrc ~/.bashrc.backup
for file in .bash_aliases .bash_functions; do
    [[ ! -e "$HOME/$file" ]] || cp -a "$HOME/$file" "$HOME/$file.backup"
    cp "$file" "$HOME/$file"
done
```

Pick the Bash configuration for the machine you are **actually using**; for example, on CORSAIR:

```bash
cp corsair.bashrc ~/.bashrc
cp -a .bash_functions.d ~/.bash_functions.d
source ~/.bashrc
```

The module directory is optional. Install it on CORSAIR if you want the ComfyUI and media commands. These commands assume `/mnt/comfyui`, `/mnt/storage/comfyui-backups`, and `/home/pmusselman/Videos/YTDL`. The other host configurations source the same shared files. If you install the modules on another machine, they will load there too, but the machine-specific commands may not work.

`root.bashrc` is for a root shell. Do not replace your regular user's `.bashrc` with it. The repo does not install files automatically or overwrite a machine's configuration without you copying them.

Optional commands depend on programs such as `ip`, `ss`, `lsof`, `git`, `curl`, `jq`, `yt-dlp`, `ffmpeg`, and `7z`. The individual commands report missing dependencies where practical.

## Check before you reload

```bash
bash -n .bash_aliases .bash_functions .bash_functions.d/*.bash *.bashrc
```

Changes are personal utilities, not a promise that every command works on every host. If you spot a useful improvement, open an issue or pull request.
