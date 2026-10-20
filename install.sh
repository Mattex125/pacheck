#!/bin/bash

# Installs pacheck into ~/.local/bin. By default it copies the script, so the
# command does not depend on this clone. Run it again to update an old copy.
# Usage: ./install.sh [--link | --uninstall]

set -eu

src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pacheck
dir=$HOME/.local/bin
dest=$dir/pacheck
mode=copy

# True if dest is a link to this clone, or a copy of pacheck (any version).
ours() {
  [[ -L $dest && $(readlink -f -- "$dest") == "$src" ]] ||
    cmp -s -- "$src" "$dest" ||
    grep -qs '^# Usage: pacheck ' -- "$dest"
}

case ${1:-} in
  "" | --copy) ;;
  --link) mode=link ;;
  --uninstall)
    if [[ ! -e $dest && ! -L $dest ]]; then
      echo "nothing to remove: $dest does not exist"
    elif ours; then
      rm -- "$dest"
      echo "removed $dest"
    else
      echo "$dest is not pacheck, leaving it alone" >&2
      exit 1
    fi
    exit 0
    ;;
  *)
    echo "usage: ./install.sh [--link | --uninstall]" >&2
    exit 2
    ;;
esac

if [[ -e $dest || -L $dest ]]; then
  if ours; then
    rm -- "$dest"
  else
    echo "$dest already exists and is not pacheck: remove it first" >&2
    exit 1
  fi
fi

mkdir -p -- "$dir"

if [[ $mode == link ]]; then
  ln -s -- "$src" "$dest"
  echo "linked $dest -> $src"
else
  install -m755 -- "$src" "$dest"
  echo "copied pacheck to $dest"
fi

case :$PATH: in
  *":$dir:"*) ;;
  *) echo "note: $dir is not in your PATH" >&2 ;;
esac
