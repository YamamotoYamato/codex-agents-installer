#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file="$script_dir/AGENTS.md"
home_dir=${CODEX_AGENTS_HOME:-$HOME}

if [ ! -f "$source_file" ]; then
    echo "AGENTS.md was not found next to install.sh." >&2
    exit 1
fi

set -- "$home_dir"/.codex*
if [ "$1" = "$home_dir/.codex*" ]; then
    echo "No .codex* directories were found in $home_dir." >&2
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
    echo "No .codex* directories were found in $home_dir." >&2
    exit 1
fi

selected=${CODEX_AGENTS_SELECT:-}
if [ -z "$selected" ]; then
    printf 'Number: '
    read -r selected
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
        y|yes)
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
        o|overwrite)
            cp "$source_file" "$destination"
            echo "Overwritten: $destination"
            ;;
        a|append)
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
