# Claude Code Hook Configuration

Add the following to your project's `.claude/settings.json` to enable the XSLT automation hooks.

Replace `<PROJECT_ROOT>` with the absolute path to your project's `.claude/hooks/` directory.

## settings.json

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash <PROJECT_ROOT>/.claude/hooks/run-xslt-after-edit.sh",
            "timeout": 30,
            "statusMessage": "Running XSLT transform..."
          },
          {
            "type": "command",
            "command": "bash <PROJECT_ROOT>/.claude/hooks/generate-xslt-from-lml.sh",
            "timeout": 35,
            "statusMessage": "Compiling LML to XSLT..."
          }
        ]
      }
    ]
  }
}
```

## What each hook does

| Hook | Trigger | Action |
|------|---------|--------|
| `run-xslt-after-edit.sh` | Any `.xslt` file written or edited | Looks up the matching `launch.json` config and calls the XSLT Debugger HTTP API to auto-run the transform |
| `generate-xslt-from-lml.sh` | Any `.lml` file written or edited | Compiles the LML file to `.xslt` via the `lml-compile` dotnet tool, writing output to `Artifacts/Maps/` |

## Prerequisites

- **`run-xslt-after-edit.sh`** — requires the XSLT Debugger VS Code extension running with HTTP API enabled (port written to `~/.xslt-debugger-port`)
- **`generate-xslt-from-lml.sh`** — requires the `lml-compile` dotnet tool project; update `TOOL_PROJECT` path inside the script to point to your local build
