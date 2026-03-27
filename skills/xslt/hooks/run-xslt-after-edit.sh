#!/bin/bash
# Hook: after Write|Edit on .xslt files, auto-run the transform via the
# XSLT Debugger extension's HTTP API. The extension activates on
# onStartupFinished — the port file exists as soon as VS Code loads.
#
# Portable: derives workspace by walking up from the edited file to find
# .vscode/launch.json. No hardcoded paths.

set -euo pipefail

PORT_FILE="$HOME/.xslt-debugger-port"

# Read hook input from stdin
INPUT=$(cat)
EDITED_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only trigger for .xslt files
[[ "$EDITED_FILE" == *.xslt ]] || exit 0

# --- Derive workspace by walking up from the file to find .vscode/launch.json ---
DIR="$(cd "$(dirname "$EDITED_FILE")" && pwd)"
WORKSPACE=""
while [[ "$DIR" != "/" ]]; do
  if [[ -f "$DIR/.vscode/launch.json" ]]; then
    WORKSPACE="$DIR"
    break
  fi
  DIR="$(dirname "$DIR")"
done

if [[ -z "$WORKSPACE" ]]; then
  jq -n --arg f "$EDITED_FILE" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("No .vscode/launch.json found above: " + $f)
    }
  }'
  exit 0
fi

LAUNCH_JSON="$WORKSPACE/.vscode/launch.json"

# Port file must exist — extension activates on startup
if [[ ! -f "$PORT_FILE" ]]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": "XSLT Debugger not running (no port file). Open VS Code with this workspace — the extension activates on startup."
    }
  }'
  exit 0
fi
PORT=$(cat "$PORT_FILE")

# Find matching launch.json config
CONFIG=$(jq -r --arg file "$EDITED_FILE" --arg ws "$WORKSPACE" '
  [.configurations[] |
   select(.type == "xslt") |
   .stylesheet as $ss |
   ($ss | gsub("\\$\\{workspaceFolder\\}"; $ws)) as $resolved |
   select($resolved == $file) |
   {
     stylesheet: $resolved,
     xml: (.xml | gsub("\\$\\{workspaceFolder\\}"; $ws)),
     engine: .engine
   }] | first // empty
' "$LAUNCH_JSON")

if [[ -z "$CONFIG" || "$CONFIG" == "null" ]]; then
  jq -n --arg f "$EDITED_FILE" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("No launch.json config found for: " + $f)
    }
  }'
  exit 0
fi

STYLESHEET=$(echo "$CONFIG" | jq -r '.stylesheet')
XML=$(echo "$CONFIG" | jq -r '.xml')
ENGINE=$(echo "$CONFIG" | jq -r '.engine')

RESULT=$(curl -s -X POST "http://127.0.0.1:$PORT/run-transform" \
  -H "Content-Type: application/json" \
  -d "{\"stylesheet\": \"$STYLESHEET\", \"xml\": \"$XML\", \"engine\": \"$ENGINE\"}" 2>&1) || true

# Filter out trace lines, keep output concise
OUTPUT=$(echo "$RESULT" | grep -v '^\[trace\]' | head -40 || true)

# Return as hook JSON so Claude sees the transform result
jq -n --arg ctx "$OUTPUT" --arg name "$(basename "$STYLESHEET")" --arg engine "$ENGINE" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ("Transform result for " + $name + " [" + $engine + "]:\n" + $ctx)
  }
}'
