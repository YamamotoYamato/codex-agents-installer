#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
install_registry_key=codex-agents.installs

# WSL 上で実行中かどうかを判定する。
is_wsl() {
    [ -f /proc/version ] && grep -qi microsoft /proc/version
}

# Windows パスを必要に応じて Unix パスへ変換する。
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

# 既定のホームディレクトリを解決する。
default_home_dir() {
    if is_wsl && [ -n "${USERPROFILE:-}" ] && command -v wslpath >/dev/null 2>&1; then
        wslpath "$USERPROFILE"
    elif is_wsl; then
        case "$repo_dir" in
            /mnt/?/Users/*/*)
                printf '%s\n' "$repo_dir" | cut -d / -f 1-5
                ;;
            *)
                printf '%s\n' "$HOME"
                ;;
        esac
    else
        printf '%s\n' "$HOME"
    fi
}

# WSL 自動起動時のみ終了確認を行う。
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

# バージョンファイルからバージョン番号を返す。
version_number_from_file() {
    basename "$1" .md
}

# 最新版のバージョン番号を返す。
latest_version_number() {
    version_number_from_file "$source_file"
}

# 最新の config.toml バージョンファイルを返す。
latest_config_file() {
    find "$version_dir" -maxdepth 1 -type f -name '*.toml' |
        sed -n 's#.*/\([0-9][0-9]*\)\.toml$#\1 &#p' |
        sort -n |
        awk 'END { print $2 }'
}

# 番号付き config.toml の管理ブロックを対象へ反映する。
apply_config_version() {
    config_file=$1
    config_version_file=$2
    [ -f "$config_version_file" ] || return 0
    mkdir -p "$(dirname "$config_file")"
    [ -f "$config_file" ] || : > "$config_file"
    before_checksum=$(cksum "$config_file")
    config_conflicts=$(perl -e '
        my ($config_file, $version_file) = @ARGV;
        local $/;
        open my $config_fh, "<:encoding(UTF-8)", $config_file or die $!;
        open my $version_fh, "<:encoding(UTF-8)", $version_file or die $!;
        my $config = <$config_fh>;
        my $version = <$version_fh>;
        my $managed = $config;
        $managed =~ s/^# BEGIN CODEX-AGENTS-INSTALLER\r?\n.*?^# END CODEX-AGENTS-INSTALLER\r?\n?//ms;
        $version =~ s/\s+\z//;
        my $has_table = $version =~ /^\s*\[\[/m;
        my @settings = ($version =~ /^([A-Za-z][A-Za-z0-9_-]*)\s*=\s*.+?\s*$/mg);
        my @conflicts = $has_table ? () : grep {
            $managed =~ /^\Q$_\E\s*=/m;
        } map {
            /^([A-Za-z][A-Za-z0-9_-]*)\s*=/;
            $1;
        } @settings;
        print join("\n", @conflicts);
        exit 0;
    ' "$config_file" "$config_version_file")
    if [ -n "$config_conflicts" ] && [ "${CODEX_AGENTS_CONFIG_OVERWRITE:-}" != "yes" ] && [ "${CODEX_AGENTS_CONFIG_OVERWRITE:-}" != "y" ]; then
        echo "管理対象外の config.toml に既存の設定があります: $(printf '%s' "$config_conflicts" | paste -sd ', ' -)"
        printf '上書きしますか？ [y/N]: '
        read -r answer
        case "$answer" in
            y|Y|yes|YES)
                ;;
            *)
                echo "config.toml の更新をスキップしました: $config_file"
                return 0
                ;;
        esac
    fi
    perl -e '
        my ($config_file, $version_file) = @ARGV;
        local $/;
        open my $config_fh, "<:encoding(UTF-8)", $config_file or die $!;
        open my $version_fh, "<:encoding(UTF-8)", $version_file or die $!;
        my $config = <$config_fh>;
        my $version = <$version_fh>;
        my $managed = $config;
        $managed =~ s/^# BEGIN CODEX-AGENTS-INSTALLER\r?\n.*?^# END CODEX-AGENTS-INSTALLER\r?\n?//ms;
        my $block = "# BEGIN CODEX-AGENTS-INSTALLER\n" .
            $version . "\n" .
            "# END CODEX-AGENTS-INSTALLER";
        $config = $managed;
        if ($config =~ /^\[/m) {
            $config =~ s/\n[ \t]*(?:\n[ \t]*)*(?=\[)/\n\n/m;
            $config =~ s/^(?=\[)/$block\n\n/m;
        } else {
            $config .= "\n" unless $config eq "" || $config =~ /\n\z/;
            $config .= "$block\n";
        }
        open my $out_fh, ">:encoding(UTF-8)", $config_file or die $!;
        print {$out_fh} $config;
    ' "$config_file" "$config_version_file"
    if [ "$before_checksum" = "$(cksum "$config_file")" ]; then
        echo "スキップしました: config.toml は既に最新版です: $config_file"
    else
        echo "config.toml を更新しました: $config_file"
    fi
}

# 最後に確認した記録を Git のグローバル設定へ保存する。
save_install_record() {
    command -v git >/dev/null 2>&1 || return 0

    version_number=$1
    checked_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    record=$(printf '%s\t%s\t%s' "$target" "$version_number" "$checked_at")
    pattern=$(printf '^%s\t' "$target" | sed 's/[.[\*^$+?{}()|\\]/\\&/g')

    git config --global --replace-all "$install_registry_key" "$record" "$pattern"
}

trap maybe_shutdown_wsl EXIT

if [ "${CODEX_AGENTS_SKIP_UPDATE:-}" != "1" ] && [ -d "$repo_dir/.git" ] && command -v git >/dev/null 2>&1; then
    echo "最新版を取得しています..."
    git -C "$repo_dir" pull --ff-only
fi

version_dir="$repo_dir/versions"
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
config_version_file=$(latest_config_file)

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
apply_config_version "$target/config.toml" "$config_version_file"
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
        save_install_record "$(latest_version_number)"
        echo "スキップしました: 最新版の AGENTS.md は既に含まれています: $destination"
        exit 0
    fi
    if [ -n "$matched_file" ]; then
        matched_version=$(version_number_from_file "$matched_file")
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
                save_install_record "$matched_version"
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
        save_install_record "$(latest_version_number)"
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
                save_install_record "$(latest_version_number)"
                echo "上書きしました: $destination"
                ;;
            a|A|append|APPEND)
                printf '\n\n' >> "$destination"
                cat "$source_file" >> "$destination"
                save_install_record "$(latest_version_number)"
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
    save_install_record "$(latest_version_number)"
    echo "インストールしました: $destination"
fi
