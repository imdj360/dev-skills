#!/usr/bin/env bash
# generate-xslt-from-lml.sh
# PostToolUse hook: when a .lml file is written/edited, compile it to XSLT
# using the lml-compile dotnet tool, then run the transform via the
# XSLT Debugger HTTP API so Claude sees the output immediately.
#
# Receives hook JSON on stdin:
#   { "tool_name": "Write"|"Edit", "tool_input": { "file_path": "..." } }

set -euo pipefail

# --- Extract file path from stdin ---
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on .lml files
case "$FILE_PATH" in
  *.lml) ;;
  *) exit 0 ;;
esac

# --- Derive output path ---
BASENAME=$(basename "$FILE_PATH" .lml)
MAPS_DIR="$(cd "$(dirname "$FILE_PATH")/.." && pwd)/Maps"
OUT_XSLT="${MAPS_DIR}/${BASENAME}.xslt"

mkdir -p "$MAPS_DIR"

# --- Compile via lml-compile tool ---
set +e
COMPILE_OUTPUT=$(lml-compile "$FILE_PATH" "$OUT_XSLT" 2>&1)
COMPILE_EXIT=$?
set -e

if [ $COMPILE_EXIT -ne 0 ]; then
  jq -n --arg err "$COMPILE_OUTPUT" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("LML compile failed: " + $err)
    }
  }'
  exit 0
fi

# --- Run the compiled XSLT via debugger HTTP API ---
# Derive workspace by walking up from the file to find .vscode/launch.json
DIR="$(cd "$(dirname "$FILE_PATH")" && pwd)"
WORKSPACE=""
while [[ "$DIR" != "/" ]]; do
  if [[ -f "$DIR/.vscode/launch.json" ]]; then
    WORKSPACE="$DIR"
    break
  fi
  DIR="$(dirname "$DIR")"
done

if [[ -z "$WORKSPACE" ]]; then
  jq -n --arg name "$(basename "$OUT_XSLT")" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("LML compiled: " + $name + ". No .vscode/launch.json found to auto-run.")
    }
  }'
  exit 0
fi

LAUNCH_JSON="$WORKSPACE/.vscode/launch.json"
PORT_FILE="$HOME/.xslt-debugger-port"

if [[ ! -f "$PORT_FILE" ]]; then
  jq -n --arg name "$(basename "$OUT_XSLT")" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("LML compiled: " + $name + ". Debugger not running — open VS Code to auto-run.")
    }
  }'
  exit 0
fi
PORT=$(cat "$PORT_FILE")

# Find matching launch config for the compiled .xslt
CONFIG=$(jq -r --arg file "$OUT_XSLT" --arg ws "$WORKSPACE" '
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
' "$LAUNCH_JSON" 2>/dev/null)

if [[ -z "$CONFIG" || "$CONFIG" == "null" ]]; then
  jq -n --arg name "$(basename "$OUT_XSLT")" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("LML compiled: " + $name + ". No launch.json config found to auto-run.")
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

OUTPUT=$(echo "$RESULT" | grep -v '^\[trace\]' | head -40 || true)

jq -n --arg ctx "$OUTPUT" --arg name "$(basename "$OUT_XSLT")" --arg engine "$ENGINE" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ("LML compiled + transform result for " + $name + " [" + $engine + "]:\n" + $ctx)
  }
}'
