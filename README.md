# codex-agents-installer

`~/.codex*` ディレクトリを選択して、Codex 用の `AGENTS.md` を配置するための小さなインストーラです。

## 使い方

`make` が入っている環境では、Windows、Linux、macOS のどれでも同じコマンドで実行できます。

```sh
make install
```

`make` を使わない場合は、OS 別のスクリプトを直接実行できます。

Windows:

```powershell
.\install.ps1
```

```sh
./install.sh
```

実行すると、ホームディレクトリ直下の `.codex`、`.codex-hattori` など `.codex*` に一致するディレクトリが表示されます。番号を入力すると、選択したディレクトリに `AGENTS.md` がコピーされます。

## テスト

実際のホームディレクトリを触らずに試す場合は、`CODEX_AGENTS_HOME` に一時ディレクトリを指定できます。

```sh
tmp=$(mktemp -d)
mkdir "$tmp/.codex" "$tmp/.codex-hattori"
CODEX_AGENTS_HOME="$tmp" CODEX_AGENTS_SELECT=1 ./install.sh
test -f "$tmp/.codex/AGENTS.md"
```

`make` が入っている場合は、次のコマンドでもテストできます。

```sh
make test
```
