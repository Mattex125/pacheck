# pacheck

An offline check for **sync database desync** on pacman systems: it tells you
whether the local sync DB has moved ahead of the installed system, which is the
state in which `pacman -S <pkg>` can cause a partial upgrade.

It is a **diagnostic**, not a safeguard. It detects a desync that already
happened; it does not prevent it and does not repair it. It is also a
**heuristic**: a clean result means *no desync was detected*, not that the
install is guaranteed to work, because undeclared dependencies (e.g. newer glibc
symbols) are invisible to pacman and to `pacheck`.

## Install

```
git clone https://github.com/Mattex125/pacheck
cd pacheck
./install.sh
```

Copies the script to `~/.local/bin/pacheck`, independent of the clone (run it
again to update). `--link` symlinks it instead, `--uninstall` removes it, and it
never overwrites a file that is not pacheck.

## Usage

```
$ pacheck qemu-desktop libvirt virt-manager dnsmasq
OK: 77 new packages, no upgrades -> sudo pacman -S qemu-desktop libvirt virt-manager dnsmasq
```

| Output | Meaning | Exit code |
|---|---|---|
| `OK: ...` | No desync detected | 0 |
| `UPGRADE: <pkg>` | The install would upgrade packages you already have | 1 |
| `WARNING: N pending upgrades` | The DB is ahead of the system | 1 |
| pacman error (e.g. unknown package) | | 2 |

It works in scripts too: `pacheck foo && sudo pacman -S foo`.

## Background

pacman keeps a local copy of the repository metadata, the sync DB
(`/var/lib/pacman/sync`). Arch assumes the DB and the installed system move
together: packages are built against the libraries of the same snapshot, and
many dependencies are not versioned tightly enough for pacman to notice a
mismatch.

| Command | Sync DB | Installed system | Result |
|---|---|---|---|
| `pacman -S pkg` | used as is | pkg installed | safe while DB and system match |
| `pacman -Sy pkg` | refreshed | not upgraded | **desync**: DB ahead of system |
| `pacman -Syu` | refreshed | upgraded | in sync again |

Desync means the DB offers newer versions than the ones installed, which is
exactly what `pacman -Qu` lists. Installing from a desynced DB can pull in
packages built against newer libraries than the ones you have.

## What it checks

Both checks are offline and need no root.

1. **Simulated install.** `pacman -S --needed --print --print-format '%n'` lists
   everything the install would touch. An already-installed package in that list
   would be upgraded. This only looks at the packages you asked for, but it
   names the ones involved.
2. **Pending upgrades.** `pacman -Qu` non-empty means the DB is ahead of the
   system. This is the general check: it catches the desync whatever you are
   about to install. Normally, if check 1 fires, this one fires too.

If either fails, `pacheck` exits 1 and tells you to update the system first.

## When it is useful

- After an **interrupted or failed system update**. Updaters that refresh the DB
  before upgrading leave it ahead of the system if they stop in between.
- After a `pacman -Sy` run by hand, by a script, or copied from a guide.
- Whenever you are not sure what state the system was left in.

## When you do not need it

If you always update with a full upgrade, install with plain `pacman -S`, and
notice when an update fails, the DB and the system never drift apart and
`pacheck` will always print `OK`. It tells you nothing you did not already know.

## What it does not do

- **It does not prevent the desync.** `sudo pacman -Sy pkg` bypasses it, and it
  only runs when you run it.
- **It does not repair anything.** The fix is a full system update.
- **It does not predict 404s.** It works offline on the local DB. If the mirror
  no longer has the old files, `pacman -S` fails with a 404. That is harmless;
  update the system instead of reaching for `pacman -Sy`.
- **AUR and other foreign packages are not covered.** pacman does not know
  them: `pacman -Qu` and the simulation ignore them, and `pacheck` exits 2 with
  "target not found" if you pass an AUR package. AUR packages built against an
  old library may need a rebuild after a system update.
- **Undeclared requirements are invisible.** The simulation only sees declared
  dependencies (sonames and explicit versions), not things like newer glibc
  symbols. This is why `OK` is not a guarantee.

## Omarchy

- `omarchy update` refreshes the sync DB (for the keyring) before it upgrades
  the system packages, so an update that stops in between leaves the DB ahead of
  the system. This is the realistic way to end up with a desync on Omarchy.
- A libalpm hook aborts a direct `pacman -Syu` that has upgrades to apply, so
  when `omarchy-update` is available `pacheck` tells you to run `omarchy update`
  instead.
- `omarchy pkg add` runs a plain `pacman -S --needed` with no desync check of
  its own, so `pacheck foo && omarchy pkg add foo` combines them.

## How it was tested

On a real, up-to-date system the output above is produced. To exercise the
`UPGRADE` branch I used a copy of the pacman database in which the installed
`glib2` provided an older soname (`libglib-2.0.so=0-32` instead of `0-64`) and
pointed `pacman` at it with `--dbpath`. `pacheck qemu-desktop` then printed
`UPGRADE: glib2` and exited with 1. This is a synthetic scenario that shows the
branch fires; it is not a case that real packages produce. The real system was
not touched. There is no automated test suite.

## License

MIT
