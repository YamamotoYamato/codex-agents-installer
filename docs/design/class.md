# Class Diagram

This repository is a shell-script installer, so the diagram describes the main responsibilities as modules rather than language-level classes.

```mermaid
classDiagram
    class InstallScript {
        +main()
        -updateRepository()
        -findLatestVersion()
        -selectTarget()
        -installAgents()
    }

    class VersionStore {
        +versionsDir
        +latestVersionFile
        +findLatest()
        +findIncludedVersion(destination)
    }

    class TargetSelector {
        +homeDir
        +defaultTarget
        +listCodexTargets()
        +readSelection()
    }

    class AgentsFile {
        +destination
        +showExisting()
        +skipIfLatest()
        +replaceMatchedVersion()
        +overwrite()
        +append()
    }

    class Environment {
        +CODEX_HOME
        +CODEX_AGENTS_HOME
        +CODEX_AGENTS_SELECT
        +CODEX_AGENTS_SAVE
        +CODEX_AGENTS_ACTION
        +CODEX_AGENTS_SKIP_UPDATE
    }

    InstallScript --> VersionStore : reads
    InstallScript --> TargetSelector : asks
    InstallScript --> AgentsFile : writes
    InstallScript --> Environment : uses
    TargetSelector --> Environment : reads defaults
    AgentsFile --> VersionStore : compares versions
```

## Responsibilities

- `InstallScript`: Coordinates the full install flow in `install.sh`.
- `VersionStore`: Finds numbered Markdown files under `versions/` and chooses the highest number as the latest version.
- `TargetSelector`: Lists `~/.codex*` directories, marks the default target, and resolves the user's selection.
- `AgentsFile`: Handles existing `AGENTS.md` content, including skip, version replacement, overwrite, and append.
- `Environment`: Provides non-interactive controls for tests and custom install locations.
