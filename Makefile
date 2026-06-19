.PHONY: install test

ifeq ($(OS),Windows_NT)
install:
	powershell -NoProfile -ExecutionPolicy Bypass -File ./install.ps1

test:
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$tmp = Join-Path $$env:TEMP ('codex-agents-test-' + [guid]::NewGuid()); New-Item -ItemType Directory -Force -Path (Join-Path $$tmp '.codex'), (Join-Path $$tmp '.codex-hattori') | Out-Null; $$env:CODEX_AGENTS_HOME = $$tmp; $$env:CODEX_AGENTS_SELECT = '2'; ./install.ps1; if (-not (Test-Path -LiteralPath (Join-Path $$tmp '.codex-hattori/AGENTS.md'))) { throw 'AGENTS.md was not installed.' }; Remove-Item Env:CODEX_AGENTS_HOME; Remove-Item Env:CODEX_AGENTS_SELECT; Remove-Item -LiteralPath $$tmp -Recurse -Force; 'Windows test OK'"
else
install:
	./install.sh

test:
	tmp=$$(mktemp -d); mkdir "$$tmp/.codex" "$$tmp/.codex-hattori"; CODEX_AGENTS_HOME="$$tmp" CODEX_AGENTS_SELECT=2 ./install.sh; test -f "$$tmp/.codex-hattori/AGENTS.md"; rm -rf "$$tmp"; echo "Unix test OK"
endif
