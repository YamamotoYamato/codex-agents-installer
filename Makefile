.PHONY: install test

ifeq ($(OS),Windows_NT)
install:
	powershell -NoProfile -ExecutionPolicy Bypass -File ./install.ps1

test:
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$tmp = Join-Path $$env:TEMP ('codex-agents-test-' + [guid]::NewGuid()); New-Item -ItemType Directory -Force -Path (Join-Path $$tmp '.codex'), (Join-Path $$tmp '.codex-hattori') | Out-Null; Set-Content -LiteralPath (Join-Path $$tmp '.codex-hattori/AGENTS.md') -Value 'existing'; $$env:CODEX_AGENTS_HOME = $$tmp; $$env:CODEX_AGENTS_SELECT = '2'; $$env:CODEX_AGENTS_ACTION = 'append'; ./install.ps1; $$installed = Get-Content -LiteralPath (Join-Path $$tmp '.codex-hattori/AGENTS.md') -Raw; if (-not $$installed.Contains('existing') -or -not $$installed.Contains('読みやすく')) { throw 'AGENTS.md was not appended.' }; Remove-Item Env:CODEX_AGENTS_HOME; Remove-Item Env:CODEX_AGENTS_SELECT; Remove-Item Env:CODEX_AGENTS_ACTION; Remove-Item -LiteralPath $$tmp -Recurse -Force; 'Windows test OK'"
else
install:
	./install.sh

test:
	tmp=$$(mktemp -d); mkdir "$$tmp/.codex" "$$tmp/.codex-hattori"; printf 'existing\n' > "$$tmp/.codex-hattori/AGENTS.md"; CODEX_AGENTS_HOME="$$tmp" CODEX_AGENTS_SELECT=2 CODEX_AGENTS_ACTION=append ./install.sh; grep -q 'existing' "$$tmp/.codex-hattori/AGENTS.md"; grep -q '読みやすく' "$$tmp/.codex-hattori/AGENTS.md"; rm -rf "$$tmp"; echo "Unix test OK"
endif
