# codex-agents-installer

`~/.codex*` ディレクトリを選択して、Codex 用の `AGENTS.md` を配置するための小さなインストーラです。

## インストール

```sh
git clone https://github.com/YamamotoYamato/codex-agents-installer.git
cd codex-agents-installer
make install
```

`make install` は最初に `git pull --ff-only` を実行し、常にリポジトリの最新版を取得してからインストールします。

実行すると、ホームディレクトリ直下の `.codex`、`.codex-hattori` など `.codex*` に一致するディレクトリが表示されます。番号を入力すると、選択したディレクトリに `AGENTS.md` がコピーされます。

選択したディレクトリに既に `AGENTS.md` がある場合は、先に内容を表示します。その後、保存するかどうかを選択できます。保存する場合は、上書きまたは追記を選択できます。

## テスト

```sh
make test
```

実際のホームディレクトリを触らずに試す場合は、`CODEX_AGENTS_HOME` に一時ディレクトリを指定できます。

```sh
tmp=$(mktemp -d)
mkdir "$tmp/.codex" "$tmp/.codex-hattori"
CODEX_AGENTS_HOME="$tmp" CODEX_AGENTS_SELECT=1 ./install.sh
test -f "$tmp/.codex/AGENTS.md"
```

既存ファイルへの追記をテストする場合は、`CODEX_AGENTS_SAVE=yes` と `CODEX_AGENTS_ACTION=append` を指定できます。
