# codex-agents-installer

`~/.codex*` ディレクトリを選択して、Codex 用の `AGENTS.md` を配置する小さなインストーラです。
インストールされる内容は `versions/` にある番号付き Markdown から選ばれます。たとえば `versions/1.md`、`versions/2.md` がある場合、最も番号が大きい `versions/2.md` が最新版として使われます。

## 必要なもの

- Git
- Bash

Windows では Git for Windows を入れると Git Bash も一緒に入ります。

```powershell
winget install Git.Git
```

macOS と Linux では通常そのまま `bash` を使えます。`make` は不要です。

## インストール

Windows では Git Bash、macOS と Linux では普段のターミナルで実行してください。PowerShell から実行して WSL の `bash` が使われた場合も、Windows 側のホームディレクトリを優先します。

```sh
git clone https://github.com/YamamotoYamato/codex-agents-installer.git
cd codex-agents-installer
bash install.sh
```

`bash install.sh` は最初に `git pull --ff-only` を実行し、常にリポジトリの最新版を取得してからインストールします。

実行すると、ホームディレクトリ直下の `.codex`、`.codex-hattori` など `.codex*` に一致するディレクトリが表示されます。`CODEX_HOME` に指定されているディレクトリが存在する場合はそこが既定値になり、存在しない場合は `~/.codex` が既定値になります。

既定値には `*` が表示され、番号を入力せずに Enter を押すとそのディレクトリが選択されます。既定ディレクトリがまだ存在しない場合は、選択時に作成されます。

選択したディレクトリに既に `AGENTS.md` がある場合は、先に内容を表示します。最新版と一致する内容が既に含まれている場合は、何も変更せずにスキップします。

`versions/` に置かれた過去版と一致する部分が既存ファイル内に見つかった場合は、現在入っているバージョンとこれから入れるバージョンを表示し、確認後にその一致部分だけを最新版に置換します。この確認は Enter のみで yes になります。

どのバージョンにも一致しない既存ファイルの場合は、上書きまたは追記を選択できます。この選択は Enter のみで上書きになります。

## テスト

実際のホームディレクトリを触らずに試す場合は、`CODEX_AGENTS_HOME` に一時ディレクトリを指定できます。

```sh
tmp=$(mktemp -d)
mkdir "$tmp/.codex" "$tmp/.codex-hattori"
CODEX_AGENTS_HOME="$tmp" CODEX_AGENTS_SELECT=1 bash install.sh
test -f "$tmp/.codex/AGENTS.md"
```

過去版の置換確認をテストする場合は、`CODEX_AGENTS_SAVE=yes` を指定できます。バージョン不明の既存ファイルへの追記をテストする場合は、`CODEX_AGENTS_ACTION=append` を指定できます。
