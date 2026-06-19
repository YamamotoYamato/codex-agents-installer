# codex-agents-installer

`~/.codex*` ディレクトリを選択して、Codex 用の `AGENTS.md` を配置するための小さなインストーラです。

## インストール

```sh
git clone https://github.com/YamamotoYamato/codex-agents-installer.git
cd codex-agents-installer
make install
```

実行すると、ホームディレクトリ直下の `.codex`、`.codex-hattori` など `.codex*` に一致するディレクトリが表示されます。番号を入力すると、選択したディレクトリに `AGENTS.md` がコピーされます。

選択したディレクトリに既に `AGENTS.md` がある場合は、先に内容を表示します。同じ内容が既に含まれている場合は中止し、含まれていない場合は上書きまたは追記を選択できます。

## make を使わない場合

Windows:

```powershell
git clone https://github.com/YamamotoYamato/codex-agents-installer.git
cd codex-agents-installer
.\install.ps1
```

Linux / macOS:

```sh
git clone https://github.com/YamamotoYamato/codex-agents-installer.git
cd codex-agents-installer
./install.sh
```

## テスト

`make` が入っている場合は、次のコマンドでテストできます。

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

既存ファイルへの追記をテストする場合は、`CODEX_AGENTS_ACTION=append` を指定できます。
