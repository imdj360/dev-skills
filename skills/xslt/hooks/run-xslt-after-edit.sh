#!/bin/bash
# Hook: after Edit on .xslt files, auto-run the transform using launch.json config
# Reads the edited file path from stdin (PostToolUse JSON), looks up the matching
# launch.json entry, and calls the XSLT Debugger HTTP API.

set -euo pipefail

WORKSPACE="$(pwd)"
LAUNCH_JSON="$WORKSPACE/.vscode/launch.json"
PORT_FILE="$HOME/.xslt-debugger-port"

# Read hook input from stdin
INPUT=$(cat)
EDITED_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only trigger for .xslt files
[[ "$EDITED_FILE" == *.xslt ]] || exit 0

# Check debugger is running
[[ -f "$PORT_FILE" ]] || { echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"XSLT Debugger not running (no port file). Start the extension to enable auto-transform."}}'; exit 0; }
PORT=$(cat "$PORT_FILE")

# Use jq to find the FIRST matching launch config
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
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"No launch.json config found for: $EDITED_FILE\"}}"
  exit 0
fi

STYLESHEET=$(echo "$CONFIG" | jq -r '.stylesheet')
XML=$(echo "$CONFIG" | jq -r '.xml')
ENGINE=$(echo "$CONFIG" | jq -r '.engine')

RESULT=$(curl -s -X POST "http://127.0.0.1:$PORT/run-transform" \
  -H "Content-Type: application/json" \
  -d "{\"stylesheet\": \"$STYLESHEET\", \"xml\": \"$XML\", \"engine\": \"$ENGINE\"}" 2>&1) || true

# Filter out trace lines, keep output concise
OUTPUT=$(echo "$RESULT" | grep -v '^\[trace\]' | head -40)

# Return as hook JSON so Claude sees the transform result
jq -n --arg ctx "$OUTPUT" --arg name "$(basename "$STYLESHEET")" --arg engine "$ENGINE" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ("Transform result for " + $name + " [" + $engine + "]:\n" + $ctx)
  }
}'
