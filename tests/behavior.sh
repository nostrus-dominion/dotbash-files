#!/usr/bin/env bash
# Isolated integration checks called by dotbash-doctor --test.
set -euo pipefail
repo_dir=${1:?checkout path required}
work=$(mktemp -d)
trap 'command rm -rf -- "$work"' EXIT
source "$repo_dir/.bash_functions"
mkdir "$work/tree"
cd "$work/tree"
printf '#!/bin/sh\nexit 0\n' > executable
chmod 0751 executable
printf hidden > .hidden
ln executable hardlink
ln -s executable symlink
mkdir empty
printf unusual > $'line\nbreak'
printf dash > ./-dash
truncate -s 16777216 sparse
python3 - <<'PY'
import os, struct
# Linux exposes POSIX ACLs as a versioned xattr. Test restoration when supported.
with open('aclfile', 'w') as f:
    f.write('ACL test')
acl = struct.pack('<I', 2) + b''.join(struct.pack('<HHI', *entry) for entry in [
    (1, 6, 0xffffffff), (2, 4, 12345), (4, 0, 0xffffffff),
    (16, 4, 0xffffffff), (32, 0, 0xffffffff)])
try:
    os.setxattr('aclfile', 'system.posix_acl_access', acl)
except OSError:
    pass
try:
    os.setxattr('executable', 'user.dotbash-test', b'preserved')
except OSError:
    pass
PY
shopt -s dotglob nullglob
before=$(shopt -p dotglob nullglob)
trap ':' USR1
before_traps=$(trap -p USR1)
store
[[ $(shopt -p dotglob nullglob) == "$before" ]]
[[ $(trap -p USR1) == "$before_traps" ]]
mkdir "$work/restored"
tar --acls --xattrs --xattrs-include='*' -xf store.tar -C "$work/restored"
python3 - "$work/restored" <<'PY'
import os, stat, sys
root = sys.argv[1]
assert stat.S_IMODE(os.stat(root + '/executable').st_mode) == 0o751
assert os.stat(root + '/executable').st_ino == os.stat(root + '/hardlink').st_ino
assert os.readlink(root + '/symlink') == 'executable'
assert os.path.isfile(root + '/line\nbreak')
assert os.path.isdir(root + '/empty')
assert os.stat(root + '/sparse').st_blocks * 512 < os.stat(root + '/sparse').st_size
try:
    expected = os.getxattr('executable', 'user.dotbash-test')
except OSError:
    expected = None
if expected is not None:
    assert os.getxattr(root + '/executable', 'user.dotbash-test') == expected
try:
    acl = os.getxattr('aclfile', 'system.posix_acl_access')
except OSError:
    acl = None
if acl is not None:
    assert os.getxattr(root + '/aclfile', 'system.posix_acl_access') == acl
PY
if store; then echo 'store replaced an existing archive' >&2; exit 1; fi
command rm store.tar
zipit
python3 - <<'PY'
import stat, zipfile
with zipfile.ZipFile('zipit.zip') as z:
    assert all(i.compress_type == zipfile.ZIP_STORED for i in z.infolist())
    assert '.hidden' in z.namelist() and 'line\nbreak' in z.namelist()
    assert 'empty/' in z.namelist() and '-dash' in z.namelist()
    assert stat.S_ISLNK(z.getinfo('symlink').external_attr >> 16)
    assert all('.dotbash-archive.' not in i.filename for i in z.infolist())
PY
if zipit; then echo 'zipit replaced an existing archive' >&2; exit 1; fi
command rm zipit.zip
mkdir "$work/dates"
cd "$work/dates"
mkdir olddir
printf old > olddir/old
printf new > olddir/new
printf old > $'old\nname'
touch -d '2020-01-01 UTC' olddir/old $'old\nname' olddir
store '2021-01-01 UTC'
zipit '2021-01-01 UTC'
python3 - <<'PY'
import tarfile, zipfile
with tarfile.open('store.tar') as t:
    names = [n.removeprefix('./') for n in t.getnames()]
    assert 'olddir/old' in names and 'olddir/new' not in names and 'old\nname' in names
with zipfile.ZipFile('zipit.zip') as z:
    assert 'olddir/old' in z.namelist() and 'olddir/new' not in z.namelist() and 'old\nname' in z.namelist()
PY
mkdir "$work/tarball"
cd "$work/tarball"
printf data > .hidden
printf data > .DS_Store
targz .
[[ -f $work/tarball.tar.gz && ! -e tarball.tar.gz ]]
mkdir "$work/extracted"
cd "$work/extracted"
extract "$work/tarball.tar.gz"
[[ -f tarball/.hidden && -f tarball/.DS_Store ]]
# Pipeline failure must not leave a final archive or alter caller options.
cd "$work/tarball"
command rm "$work/tarball.tar.gz"
gzip() { return 9; }
pigz() { return 9; }
if targz .; then echo 'targz accepted a failed compressor' >&2; exit 1; fi
unset -f gzip pigz
[[ ! -e $work/tarball.tar.gz ]]
[[ -z $(find "$work" -name '.dotbash-archive.*' -print) ]]
mkdir "$work/links"
cd "$work/links"
ln -s missing store.tar
if store; then echo 'store replaced a dangling output symlink' >&2; exit 1; fi
ln -s missing zipit.zip
if zipit; then echo 'zipit replaced a dangling output symlink' >&2; exit 1; fi
python3 "$repo_dir/tests/installer.py" "$repo_dir" "$work"
printf 'Archive metadata, date filters, subshell isolation, extraction and installer migration: OK\n'
