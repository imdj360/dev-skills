# dev-skills

A collection of skills for AI coding agents (Claude Code, Codex, Gemini CLI, etc).

## Structure

```
skills/
  <skill-name>/
    SKILL.md          # Skill definition and usage guide
    hooks/            # Shell scripts for automation hooks
    references/       # Supporting reference documentation
tools/
  <tool-name>/        # Companion CLI tools used by skill hooks
```

## Skills

### [xslt](skills/xslt/SKILL.md)

Expert XSLT authoring, debugging, migration, and platform-compatibility skill for XML transformation work. Covers:

- XSLT 1.0 (including `msxsl:script` inline C#), 2.0, and 3.0 / SaxonCS
- BizTalk / XslCompiledTransform, Logic Apps Transform XML, Saxon / SaxonCS
- Generate, Debug, Migrate, Compatibility, and LML (Logic Apps Data Mapper) modes
- Ready-to-debug output bundles with launch.json for the XSLT Debugger VS Code extension

**Hooks:**
- `generate-xslt-from-lml.sh` — auto-compiles `.lml` files to `.xslt` on save
- `run-xslt-after-edit.sh` — auto-runs transforms via the XSLT Debugger HTTP API after `.xslt` edits

**References:** BizTalk, Logic Apps, Saxon/SaxonCS quirks, version migration, LML format, Claude Code hook setup

**Tools:**
- [`lml-compile`](tools/lml-compile/) — dotnet global tool that compiles `.lml` (Logic Apps Data Mapper) files to `.xslt`. Required by `generate-xslt-from-lml.sh`.

  ```bash
  dotnet tool install --global lml-compile --add-source tools/lml-compile/nupkg
  ```
