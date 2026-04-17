#!/bin/bash
set -e

TARGET="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$TARGET" ]; then
  echo "Directory $TARGET does not exist."
  exit 1
fi

mkdir -p "$TARGET/.claude/commands" "$TARGET/.claude/agents"

echo "Installing commands..."
for cmd in "$SCRIPT_DIR"/commands/*.md; do
  name=$(basename "$cmd")
  ln -sf "$cmd" "$TARGET/.claude/commands/$name"
  echo "  $name"
done

echo "Installing agents..."
for agent in "$SCRIPT_DIR"/agents/*.md; do
  name=$(basename "$agent")
  ln -sf "$agent" "$TARGET/.claude/agents/$name"
  echo "  $name"
done

echo ""
echo "Done. Commands and agents installed to $TARGET/.claude/"
echo "Available commands: /dev, /ci-monitor"
