# claude-beeps as a plugin (experimental, side by side with the installer)

This branch carries a second install path: a Claude Code **plugin** that
ships the same three hook scripts without ever writing to your
`~/.claude/settings.json`. The classic installer under `windows/` still
works and is unchanged in behavior; pick one path per machine, not both,
or every event beeps twice.

## Why a plugin

The installer's whole risk surface is the read-modify-write merge it does
on `settings.json` - a file the user, Claude Code, and other tools also
write. The plugin route deletes that surface:

- Hooks live in `hooks/hooks.json` **in this repo** - authored by hand,
  validated in CI, never re-serialized by PowerShell.
- Claude Code merges plugin hooks with user/project hooks in memory at
  load time. Nothing edits anyone's settings file except Claude Code
  itself (it records `enabledPlugins` in the scope you pick at install).
- `${CLAUDE_PLUGIN_ROOT}` replaces the `<USERNAME>` path substitution.
- Uninstall is `/plugin uninstall`, not a settings-file surgery script.

The hook entries use **exec form** (`command` + `args`): no shell parses
the command line, so backslashes, spaces in paths, and usernames with
special characters are all safe, and Git Bash is not required.

## Install

```
/plugin marketplace add dsopko/claude-beeps
/plugin install claude-beeps@claude-beeps
```

Pick **user scope** when prompted (you want beeps everywhere, and project
scope would make the hooks fire for collaborators and cloud sessions).
If the install summary says `Run /reload-plugins to activate.`, run that.

For development without installing:

```
claude --plugin-dir /path/to/claude-beeps
```

## Windows only - by design

There is no platform-gating field anywhere in the plugin system
(`plugin.json`, marketplace entries, and `hooks.json` were all checked),
so an installed plugin's hooks fire on every OS. Two layers keep that
harmless here:

1. On macOS/Linux, `powershell` usually isn't on `PATH`, so the hook
   fails as a non-blocking error.
2. Each hook script now opens with a guard - `if ($env:OS -ne
   'Windows_NT') { exit 0 }` - so anywhere PowerShell *does* exist
   off-Windows (pwsh on Linux/macOS, cloud sessions), the hook exits
   quietly with no error notice and no attempt at the Windows-only
   `[console]::beep` API.

If you want silence instead of a per-turn hook-error notice on a Mac,
install PowerShell there or just don't enable the plugin on that machine
(local scope exists for exactly this).

## What changes vs the classic installer

| | Installer (`windows/`) | Plugin |
|---|---|---|
| settings.json | merged/rewritten by PowerShell | untouched (Claude Code adds one `enabledPlugins` line) |
| Per-machine templating | `<USERNAME>` substitution | `${CLAUDE_PLUGIN_ROOT}`, resolved at fire time |
| Uninstall | `uninstall-<PID>.ps1` | `/plugin uninstall claude-beeps@claude-beeps` |
| Hot-editing sounds | edit `~/.claude/hooks/*.ps1`, live next event | edit files in the versioned plugin cache - **wiped on plugin update** |
| Updates | re-run installer | bump `version` in `.claude-plugin/plugin.json` |

The hot-edit caveat is real: customizations belong in the repo (then bump
the version) rather than in the cache copy. A config file under
`${CLAUDE_PLUGIN_DATA}` (survives updates) is the eventual fix; not built
yet.

## Also ships

Because the plugin root is the repo root, `skills/commit-messages`
rides along and appears as `/claude-beeps:commit-messages`. Move it out
of `skills/` before tagging a release if you don't want the plugin to
carry it.
