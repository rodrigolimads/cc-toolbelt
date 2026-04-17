#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

print_usage() {
  echo "Usage: ./install.sh [--global | /path/to/project]"
  echo ""
  echo "  --global    Install to ~/.claude/ (available in all projects)"
  echo "  <path>      Install to a specific project's .claude/ directory"
  echo "  (no args)   Same as --global"
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  print_usage
  exit 0
fi

if [ "$1" = "--global" ] || [ -z "$1" ]; then
  TARGET="$HOME/.claude"
  echo "Installing globally to $TARGET"
else
  TARGET="$1/.claude"
  echo "Installing to project: $TARGET"
fi

mkdir -p "$TARGET/commands" "$TARGET/agents" "$TARGET/skills"

echo ""
echo "Commands:"
for cmd in "$SCRIPT_DIR"/commands/*.md; do
  name=$(basename "$cmd")
  ln -sf "$cmd" "$TARGET/commands/$name"
  echo "  /$( echo "$name" | sed 's/.md//' )"
done

echo ""
echo "Agents:"
for agent in "$SCRIPT_DIR"/agents/*.md; do
  name=$(basename "$agent")
  ln -sf "$agent" "$TARGET/agents/$name"
  echo "  $name"
done

if [ -d "$SCRIPT_DIR/skills" ] && [ -n "$(ls -A "$SCRIPT_DIR/skills" 2>/dev/null)" ]; then
  echo ""
  echo "Skills:"
  for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    name=$(basename "$skill_dir")
    ln -sfn "$skill_dir" "$TARGET/skills/$name"
    echo "  $name"
  done
fi

echo ""
echo "Done. Run /dev, /ci-monitor, or /ci-gamekeeper in Claude Code."
