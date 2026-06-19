#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
version_dir="$script_dir/versions"
source_file=$(find "$version_dir" -maxdepth 1 -type f -name '*.md' |
    sed -n 's#.*/\([0-9][0-9]*\)\.md$#\1 &#p' |
    sort -n |
    awk 'END { print $2 }')
home_dir=${CODEX_AGENTS_HOME:-$HOME}
if [ -n "${CODEX_HOME:-}" ] && [ -d "$CODEX_HOME" ]; then
    default_target=$CODEX_HOME
else
    default_target=$home_dir/.codex
fi

if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
    echo "No numbered AGENTS.md versions were found in $version_dir." >&2
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

    if perl -0e '
        my ($destination, $source_file) = @ARGV;
        open my $existing_fh, "<:encoding(UTF-8)", $destination or die $!;
        open my $source_fh, "<:encoding(UTF-8)", $source_file or die $!;
        local $/;
        my $existing = <$existing_fh>;
        my $source = <$source_fh>;
        exit(($source ne "" && index($existing, $source) >= 0) ? 0 : 1);
    ' "$destination" "$source_file"
    then
        echo "Abort: latest AGENTS.md version is already included in $destination." >&2
        exit 1
    fi

    matched_file=
    if [ -d "$version_dir" ]; then
        for version_file in "$version_dir"/*.md; do
            [ -f "$version_file" ] || continue
            [ "$version_file" != "$source_file" ] || continue
            if perl -0e '
                my ($destination, $version_file) = @ARGV;
                open my $existing_fh, "<:encoding(UTF-8)", $destination or die $!;
                open my $version_fh, "<:encoding(UTF-8)", $version_file or die $!;
                local $/;
                my $existing = <$existing_fh>;
                my $version = <$version_fh>;
                exit(($version ne "" && index($existing, $version) >= 0) ? 0 : 1);
            ' "$destination" "$version_file"
            then
                matched_file=$version_file
                break
            fi
        done
    fi
    if [ -n "$matched_file" ]; then
        echo "Current version: $(basename "$matched_file")"
        echo "Install version: $(basename "$source_file")"
        save=${CODEX_AGENTS_SAVE:-}
        if [ -z "$save" ]; then
            printf 'Replace matched version? [Y/n]: '
            read -r save
        fi
        case "$save" in
            ''|y|Y|yes|YES)
                ;;
            *)
                echo "Skipped: $destination"
                exit 0
                ;;
        esac
        perl -e '
            my ($destination, $matched_file, $source_file) = @ARGV;
            local $/;
            open my $destination_fh, "<:encoding(UTF-8)", $destination or die $!;
            open my $old_fh, "<:encoding(UTF-8)", $matched_file or die $!;
            open my $new_fh, "<:encoding(UTF-8)", $source_file or die $!;
            my $existing = <$destination_fh>;
            my $old = <$old_fh>;
            my $new = <$new_fh>;
            $existing =~ s/\Q$old\E/$new/g;
            open my $out_fh, ">:encoding(UTF-8)", $destination or die $!;
            print {$out_fh} $existing;
        ' "$destination" "$matched_file" "$source_file"
        echo "Replaced matched version: $destination"
    else
        printf '\n\n' >> "$destination"
        cat "$source_file" >> "$destination"
        echo "Appended: $destination"
    fi
else
    cp "$source_file" "$destination"
    echo "Installed: $destination"
fi
