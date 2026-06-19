#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file="$script_dir/AGENTS.md"
home_dir=${CODEX_AGENTS_HOME:-$HOME}
if [ -n "${CODEX_HOME:-}" ] && [ -d "$CODEX_HOME" ]; then
    default_target=$CODEX_HOME
else
    default_target=$home_dir/.codex
fi

if [ ! -f "$source_file" ]; then
    echo "AGENTS.md was not found next to install.sh." >&2
    exit 1
fi

set -- "$home_dir"/.codex*
targets=""
count=0
for path in "$@"; do
    if [ -d "$path" ]; then
        count=$((count + 1))
        targets="${targets}${path}
"
    fi
done

has_default=0
while IFS= read -r path; do
    if [ "$path" = "$default_target" ]; then
        has_default=1
        break
    fi
done <<EOF
$targets
EOF

if [ "$has_default" -eq 0 ]; then
    count=$((count + 1))
    targets="${targets}${default_target}
"
fi

default_index=0
index=0
printf 'Select install target (Enter selects *):\n'
while IFS= read -r path; do
    [ -n "$path" ] || continue
    index=$((index + 1))
    if [ "$path" = "$default_target" ]; then
        default_index=$index
        marker='*'
    else
        marker=' '
    fi
    printf '%s [%s] %s\n' "$marker" "$index" "$path"
done <<EOF
$targets
EOF

if [ "$default_index" -eq 0 ]; then
    echo "Default target was not found: $default_target" >&2
    exit 1
fi

selected=${CODEX_AGENTS_SELECT:-}
if [ -z "$selected" ]; then
    printf 'Number: '
    read -r selected
fi
if [ -z "$selected" ]; then
    selected=$default_index
fi

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
mkdir -p "$target"
destination="$target/AGENTS.md"

if [ -f "$destination" ]; then
    echo "Existing AGENTS.md:"
    echo "---"
    cat "$destination"
    echo "---"

    save=${CODEX_AGENTS_SAVE:-}
    if [ -z "$save" ]; then
        printf 'Save changes? [y/N]: '
        read -r save
    fi

    case "$save" in
        y|Y|yes|YES)
            ;;
        *)
            echo "Skipped: $destination"
            exit 0
            ;;
    esac

    action=${CODEX_AGENTS_ACTION:-}
    if [ -z "$action" ]; then
        printf 'Action ([O]verwrite / [a]ppend): '
        read -r action
    fi
    if [ -z "$action" ]; then
        action=overwrite
    fi

    case "$action" in
        o|O|overwrite|OVERWRITE)
            cp "$source_file" "$destination"
            echo "Overwritten: $destination"
            ;;
        a|A|append|APPEND)
            printf '\n\n' >> "$destination"
            cat "$source_file" >> "$destination"
            echo "Appended: $destination"
            ;;
        *)
            echo "Invalid action: $action" >&2
            exit 1
            ;;
    esac
else
    cp "$source_file" "$destination"
    echo "Installed: $destination"
fi
