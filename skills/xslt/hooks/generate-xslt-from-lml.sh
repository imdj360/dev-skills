#!/usr/bin/env bash
# generate-xslt-from-lml.sh
# PostToolUse hook: when a .lml file is written/edited, compile it to XSLT
# using the lml-compile dotnet tool (no running host required).
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
OUTPUT=$(lml-compile "$FILE_PATH" "$OUT_XSLT" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  echo "{\"systemMessage\": \"XSLT compiled: $(basename "$OUT_XSLT")\"}"
else
  echo "{\"systemMessage\": \"LML compile failed: $OUTPUT\"}"
fi
