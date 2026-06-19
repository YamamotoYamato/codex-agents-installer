# codex-agents-installer

`~/.codex*` ディレクトリを選択して、Codex 用の `AGENTS.md` を配置するための小さなインストーラです。

## 使い方

### Windows

```powershell
.\install.ps1
```

### Linux / macOS

```sh
chmod +x ./install.sh
./install.sh
```

実行すると、ホームディレクトリ直下の `.codex`、`.codex-hattori` など `.codex*` に一致するディレクトリが表示されます。番号を入力すると、選択したディレクトリに `AGENTS.md` がコピーされます。
