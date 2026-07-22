# codex-agents-installer

`~/.codex*` ディレクトリを選択して、Codex 用の `AGENTS.md` を配置する小さなインストーラです。
インストールされる内容は `versions/` にある番号付き Markdown と TOML から選ばれます。Markdown は `AGENTS.md` 用、TOML は選択したディレクトリ直下の `config.toml` 用です。それぞれ最も番号が大きいファイルが最新版として使われます。
実行のたびに、対象ディレクトリ・バージョン・最後に確認した日時を Git のグローバル設定へ記録します。

## 必要なもの

- Git
- Bash

Windows では Git for Windows を入れると Git Bash も一緒に入ります。

```powershell
winget install Git.Git
```

macOS と Linux では通常そのまま `bash` を使えます。

## インストール

Windows では Git Bash、macOS と Linux では普段のターミナルで実行してください。PowerShell から `bash` を実行すると WSL が自動起動することがあります。その場合も Windows 側のホームディレクトリを優先し、最後に WSL を終了するか確認します。

```sh
git clone https://github.com/YamamotoYamato/codex-agents-installer.git
cd codex-agents-installer
./codex-agents-installer
```

Windows の PowerShell または `cmd.exe` では次でも実行できます。

```powershell
.\codex-agents-installer.cmd
```

`codex-agents-installer` は最初に `git pull --ff-only` を実行し、常にリポジトリの最新版を取得してからインストールします。

## インストール状況の確認

インストール済みの場所、バージョン、日時は OS 共通で次のコマンドから確認できます。

```sh
./codex-agents-installer --status
```

```sh
./codex-agents-installer -s
```

Windows の PowerShell または `cmd.exe` では次でも確認できます。

```powershell
.\codex-agents-installer.cmd --status
```

```powershell
.\codex-agents-installer.cmd -s
```

内部的には Git のグローバル設定を読んでおり、出力は 1 行につき 1 ディレクトリで、`インストール先<TAB>バージョン<TAB>最後に確認した日時(UTC)` の順です。

```text
/home/me/.codex    10    2026-07-02T01:23:45Z
```

この記録は内部スクリプトによる新規インストール、置換、上書き、追記の成功時だけでなく、最新版が既に含まれていてスキップされた場合や、置換を行わずにスキップした場合にも更新されます。スキップ時は、その時点で対象ディレクトリに入っているバージョンを記録します。

実行すると、ホームディレクトリ直下の `.codex`、`.codex-hattori` など `.codex*` に一致するディレクトリが表示されます。`CODEX_HOME` に指定されているディレクトリが存在する場合はそこが既定値になり、存在しない場合は `~/.codex` が既定値になります。

既定値には `*` が表示され、番号を入力せずに Enter を押すとそのディレクトリが選択されます。既定ディレクトリがまだ存在しない場合は、選択時に作成されます。

選択したディレクトリに既に `AGENTS.md` がある場合は、先に内容を表示します。最新版と一致する内容が既に含まれている場合は、何も変更せずにスキップします。

選択したディレクトリ直下の `config.toml` には、`versions/` の番号付き TOML にある設定を、`CODEX-AGENTS-INSTALLER` のコメント付き管理ブロックとして反映します。トップレベル設定だけでなく、`[notice]` などのテーブル配下の設定も更新できます。現在は `versions/1.toml` により `model_context_window = 136000` を設定します。新しいバージョンで項目を削除すると、管理ブロックからも削除されます。

管理ブロック外に同じ設定が既にある場合は、上書き前に確認します。自動実行時に上書きを許可する場合は `CODEX_AGENTS_CONFIG_OVERWRITE=yes` を指定します。

`config.toml` の反映結果は、`AGENTS.md` の処理結果とは別にターミナルへ表示します。

`versions/` に置かれた過去版と一致する部分が既存ファイル内に見つかった場合は、現在入っているバージョンとこれから入れるバージョンを表示し、確認後にその一致部分だけを最新版に置換します。この確認は Enter のみで yes になります。

どのバージョンにも一致しない既存ファイルの場合は、上書きまたは追記を選択できます。この選択は Enter のみで上書きになります。

## テスト

実際のホームディレクトリを触らずに試す場合は、`CODEX_AGENTS_HOME` に一時ディレクトリを指定できます。

```sh
tmp=$(mktemp -d)
mkdir "$tmp/.codex" "$tmp/.codex-hattori"
CODEX_AGENTS_HOME="$tmp" CODEX_AGENTS_SELECT=1 CODEX_AGENTS_SKIP_UPDATE=1 ./codex-agents-installer
test -f "$tmp/.codex/AGENTS.md"
```

過去版の置換確認をテストする場合は、`CODEX_AGENTS_SAVE=yes` を指定できます。バージョン不明の既存ファイルへの追記をテストする場合は、`CODEX_AGENTS_ACTION=append` を指定できます。
WSL 終了確認を自動化する場合は、`CODEX_AGENTS_SHUTDOWN_WSL=yes` または `CODEX_AGENTS_SHUTDOWN_WSL=no` を指定できます。
