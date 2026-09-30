"""Run the real user installer with an isolated HOME and controlling terminal."""
import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import sys
import termios
import time

repo, scratch = map(Path, sys.argv[1:])
home = scratch / 'home'
home.mkdir()
env = os.environ.copy()
for key in list(env):
    if key.startswith('GIT_'):
        env.pop(key)
env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
           XDG_STATE_HOME=str(home / '.local/state'), TERM='xterm', LC_ALL='C')

def install(answers):
    master, slave = pty.openpty()
    def terminal():
        os.setsid()
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)
    process = subprocess.Popen(['bash', '-c', 'source "$1/install.sh"; install_user', 'test', str(repo)],
                               stdin=slave, stdout=slave, stderr=slave, env=env,
                               cwd=repo, preexec_fn=terminal)
    os.close(slave)
    # Answers queue in the terminal; read /dev/tty consumes them normally.
    os.write(master, ('\n'.join(answers) + '\n').encode())
    output = b''
    deadline = time.monotonic() + 20
    try:
        while True:
            if time.monotonic() > deadline:
                process.kill()
                raise AssertionError('Installer timed out: ' + output.decode(errors='replace'))
            ready, _, _ = select.select([master], [], [], .1)
            if ready:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not chunk:
                    break
                output += chunk
            elif process.poll() is not None:
                break
        assert process.wait(timeout=2) == 0, output.decode(errors='replace')
    finally:
        os.close(master)
        if process.poll() is None:
            process.kill()
            process.wait()
    return output.decode(errors='replace')

def git(*args):
    return subprocess.check_output(['git', *args], env=env, text=True).strip()

# Legacy installation with a local override that must continue to win.
(home / '.bash_prompt').write_text("PS1='legacy prompt> '\n")
config = home / '.config/dotbash-files'
config.mkdir(parents=True)
(config / 'history').write_text('-1\n')
(home / '.local').mkdir()
(home / '.local/gitconfig').write_text('[user]\n name = Test User\n email = test@example.invalid\n[credential]\n helper = cache\n helper = custom-helper\n[alias]\n hi = status --short\n')
(home / '.gitconfig').write_text(f'[include]\n path = {home}/.local/gitconfig\n[credential]\n helper = native-helper\n[core]\n editor = vim\n')
(home / '.bash_local').write_text("# Keep this private code exactly\nPS1='my override> '\nalias personal='true'\n")
# User declines changing prompt, history, and Git identity.
install(['y', 'n', 'n', 'n'])
local = home / '.bash_local'
first = local.read_bytes()
assert b"PS1='my override> '" in first
assert local.stat().st_mode & 0o777 == 0o600
assert not (home / '.bash_prompt').exists()
assert not (config / 'history').exists()
assert not (home / '.local/gitconfig').exists()
assert git('config', '--global', '--get', 'core.editor') == 'vim'
assert git('config', '--global', '--get', 'alias.hi') == 'status --short'
assert git('config', '--global', '--get-all', 'credential.helper').splitlines() == ['native-helper', 'cache', 'custom-helper']
assert subprocess.run(['git', 'config', '--global', '--get-all', 'include.path'], env=env, capture_output=True).returncode == 1
# Bash startup must apply the user override last, and session-only history.
result = subprocess.check_output(['bash', '--noprofile', '--rcfile', str(home / '.bashrc'), '-ic',
                                 'printf "%s|%s|%s|%s" "$PS1" "$HISTFILE" "$HISTSIZE" "$GIT_AUTHOR_NAME"'],
                                env=env, stderr=subprocess.DEVNULL, text=True)
assert result == 'my override> |/dev/null|32768|Test User', result
# Different seconds avoid the installer's deliberate backup collision guard.
# Backups use mktemp suffixes, so back-to-back installs are supported.
install(['y', 'n', 'n', 'n'])
assert local.read_bytes() == first, 'Unchanged settings modified private local code'
assert (home / '.local/bin/dotbash-doctor').is_symlink()
assert not (home / '.local/bin/test.sh').exists()
reference = subprocess.check_output([str(home / '.local/bin/my-commands')], env=env, text=True)
assert all(name in reference for name in ('zipit', 'store', 'targz', 'dotbash-doctor'))
assert '_dotbash_bundle' not in reference
# Exercise both zero and bounded history choices, keeping custom content.
for choice in ('0', '32768'):
    install(['y', 'n', 'y', choice, 'n'])
    result = subprocess.check_output(['bash', '--noprofile', '--rcfile', str(home / '.bashrc'), '-ic',
                                     'printf "%s|%s" "$HISTSIZE" "$HISTFILE"'], env=env,
                                    stderr=subprocess.DEVNULL, text=True)
    assert result == (f'0|/dev/null' if choice == '0' else f'32768|{home}/.bash_history'), result
# Doctor through the installed symlink must locate the checkout from any CWD.
subprocess.run([str(home / '.local/bin/dotbash-doctor'), '--check'], cwd=scratch,
               env=env, check=True, stdout=subprocess.DEVNULL)

# Fresh install, preserving default colors/history/identity on the next run.
home = scratch / 'fresh-home'
home.mkdir()
env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
           XDG_STATE_HOME=str(home / '.local/state'), GIT_CONFIG_NOSYSTEM='1')
install(['y', '1', '4', '1000', 'Fresh User', 'fresh@example.invalid'])
fresh = (home / '.bash_local').read_bytes()
assert b'PS1=' in fresh and b'HISTSIZE=1000' in fresh
install(['y', 'n', 'n', 'n'])
assert (home / '.bash_local').read_bytes() == fresh
assert git('config', '--global', '--get', 'user.name') == 'Fresh User'
assert not (home / '.bash_prompt').exists()

# Regression: Bash checks must not silently ignore files after the first argument.
copy = scratch / 'broken-checkout'
shutil.copytree(repo, copy, ignore=shutil.ignore_patterns('.git'))
for name in ('.bash_exports', '.bash_functions'):
    with (copy / name).open('a') as f:
        f.write('\nif then\n')
result = subprocess.run([str(copy / 'bin/dotbash-doctor'), '--check'], env=env,
                        capture_output=True, text=True)
assert result.returncode == 1
assert '.bash_exports' in result.stderr and '.bash_functions' in result.stderr
