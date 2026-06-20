#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

is_wsl() {
    [ -f /proc/version ] && grep -qi microsoft /proc/version
}

to_unix_path() {
    case "$1" in
        [A-Za-z]:\\*)
            if command -v wslpath >/dev/null 2>&1; then
                wslpath "$1"
            else
                printf '%s\n' "$1"
            fi
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

default_home_dir() {
    if is_wsl && [ -n "${USERPROFILE:-}" ] && command -v wslpath >/dev/null 2>&1; then
        wslpath "$USERPROFILE"
    elif is_wsl; then
        case "$script_dir" in
            /mnt/?/Users/*/*)
                printf '%s\n' "$script_dir" | cut -d / -f 1-5
                ;;
            *)
                printf '%s\n' "$HOME"
                ;;
        esac
    else
        printf '%s\n' "$HOME"
    fi
}

maybe_shutdown_wsl() {
    is_wsl || return 0
    command -v wsl.exe >/dev/null 2>&1 || return 0

    shutdown=${CODEX_AGENTS_SHUTDOWN_WSL:-}
    if [ -z "$shutdown" ]; then
        [ -t 0 ] || return 0
        echo "このインストーラは WSL 上で実行されました。PowerShell から bash を実行した場合、WSL が自動起動していることがあります。"
        printf 'WSL を終了しますか？ [y/N]: '
        read -r shutdown || return 0
    fi

    case "$shutdown" in
        y|Y|yes|YES)
            echo "WSL を終了します..."
            wsl.exe --shutdown >/dev/null 2>&1 || echo "WSL の終了に失敗しました。" >&2
            ;;
    esac
}

trap maybe_shutdown_wsl EXIT

if [ "${CODEX_AGENTS_SKIP_UPDATE:-}" != "1" ] && [ -d "$script_dir/.git" ] && command -v git >/dev/null 2>&1; then
    echo "最新版を取得しています..."
    git -C "$script_dir" pull --ff-only
fi

version_dir="$script_dir/versions"
source_file=$(find "$version_dir" -maxdepth 1 -type f -name '*.md' |
    sed -n 's#.*/\([0-9][0-9]*\)\.md$#\1 &#p' |
    sort -n |
    awk 'END { print $2 }')
if [ -n "${CODEX_AGENTS_HOME:-}" ]; then
    home_dir=$(to_unix_path "$CODEX_AGENTS_HOME")
else
    home_dir=$(default_home_dir)
fi

codex_home=${CODEX_HOME:-}
if [ -n "$codex_home" ]; then
    codex_home=$(to_unix_path "$codex_home")
fi
if [ -n "$codex_home" ] && [ -d "$codex_home" ]; then
    default_target=$codex_home
else
    default_target=$home_dir/.codex
fi

if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
    echo "番号付きの AGENTS.md バージョンが見つかりません: $version_dir" >&2
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
printf 'インストール先を選択してください（Enter で * を選択）:\n'
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
    echo "既定のインストール先が見つかりません: $default_target" >&2
    exit 1
fi

selected=${CODEX_AGENTS_SELECT:-}
if [ -z "$selected" ]; then
    printf '番号: '
    read -r selected
fi
if [ -z "$selected" ]; then
    selected=$default_index
fi

case "$selected" in
    ''|*[!0-9]*)
        echo "無効な選択です: $selected" >&2
        exit 1
        ;;
esac

if [ "$selected" -lt 1 ] || [ "$selected" -gt "$count" ]; then
    echo "無効な選択です: $selected" >&2
    exit 1
fi

target=$(printf '%s' "$targets" | sed -n "${selected}p")
mkdir -p "$target"
destination="$target/AGENTS.md"

if [ -f "$destination" ]; then
    echo "既存の AGENTS.md:"
    echo "---"
    cat "$destination"
    echo
    echo "---"

    matched_file=
    if [ -d "$version_dir" ]; then
        matched_length=-1
        matched_number=-1
        for version_file in "$version_dir"/*.md; do
            [ -f "$version_file" ] || continue
            version_number=$(basename "$version_file" .md)
            case "$version_number" in
                ''|*[!0-9]*)
                    continue
                    ;;
            esac
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
                version_length=$(wc -c < "$version_file")
                if [ "$version_length" -gt "$matched_length" ] ||
                    { [ "$version_length" -eq "$matched_length" ] && [ "$version_number" -gt "$matched_number" ]; }; then
                    matched_file=$version_file
                    matched_length=$version_length
                    matched_number=$version_number
                fi
            fi
        done
    fi
    if [ "$matched_file" = "$source_file" ]; then
        echo "スキップしました: 最新版の AGENTS.md は既に含まれています: $destination"
        exit 0
    fi
    if [ -n "$matched_file" ]; then
        echo "現在のバージョン: $(basename "$matched_file")"
        echo "インストールするバージョン: $(basename "$source_file")"
        save=${CODEX_AGENTS_SAVE:-}
        if [ -z "$save" ]; then
            printf '一致した部分を置換しますか？ [Y/n]: '
            read -r save
        fi
        case "$save" in
            ''|y|Y|yes|YES)
                ;;
            *)
                echo "スキップしました: $destination"
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
        echo "一致したバージョンを置換しました: $destination"
    else
        action=${CODEX_AGENTS_ACTION:-}
        if [ -z "$action" ]; then
            printf '既知のバージョンに一致しません。操作を選択してください ([O] 上書き / [a] 追記): '
            read -r action
        fi
        if [ -z "$action" ]; then
            action=overwrite
        fi

        case "$action" in
            o|O|overwrite|OVERWRITE)
                cp "$source_file" "$destination"
                echo "上書きしました: $destination"
                ;;
            a|A|append|APPEND)
                printf '\n\n' >> "$destination"
                cat "$source_file" >> "$destination"
                echo "追記しました: $destination"
                ;;
            *)
                echo "無効な操作です: $action" >&2
                exit 1
                ;;
        esac
    fi
else
    cp "$source_file" "$destination"
    echo "インストールしました: $destination"
fi
