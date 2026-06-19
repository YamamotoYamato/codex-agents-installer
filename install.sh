#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file="$script_dir/AGENTS.md"

if [ ! -f "$source_file" ]; then
    echo "AGENTS.md was not found next to install.sh." >&2
    exit 1
fi

set -- "$HOME"/.codex*
if [ "$1" = "$HOME/.codex*" ]; then
    echo "No .codex* directories were found in $HOME." >&2
    exit 1
fi

targets=""
count=0
for path in "$@"; do
    if [ -d "$path" ]; then
        count=$((count + 1))
        targets="${targets}${path}
"
        printf '[%s] %s\n' "$count" "$path"
    fi
done

if [ "$count" -eq 0 ]; then
    echo "No .codex* directories were found in $HOME." >&2
    exit 1
fi

printf 'Number: '
read -r selected
case "$selected" in
    ''|*[!0-9]*)
        echo "Invalid selection: $selected" >&2
        exit 1
        ;;
esac

if [ "$selected" -lt 1 ] || [ "$selected" -gt "$count" ]; then
    echo "Invalid selection: $selected" >&2
    exit 1
fi

target=$(printf '%s' "$targets" | sed -n "${selected}p")
destination="$target/AGENTS.md"
cp "$source_file" "$destination"
echo "Installed: $destination"
