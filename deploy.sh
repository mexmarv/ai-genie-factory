#!/usr/bin/env bash
# Deploy AI Genie Factory to Databricks Genie Code
# Usage:
#   ./deploy.sh                    # deploy to your personal .assistant folder
#   ./deploy.sh --workspace        # deploy workspace-wide (requires admin)
#   ./deploy.sh --profile myprof   # use a specific ~/.databrickscfg profile

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
EMAIL="marvin.nahmias@alpura.com"
PROFILE="DEFAULT"
PERSONAL_BASE="/Users/${EMAIL}/.assistant"
WORKSPACE_BASE="/Workspace/.assistant"
TARGET_BASE="$PERSONAL_BASE"

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --workspace) TARGET_BASE="$WORKSPACE_BASE"; shift ;;
    --profile)   PROFILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

SKILLS_TARGET="${TARGET_BASE}/skills"
INSTRUCTIONS_TARGET="${TARGET_BASE}/instructions.md"
CLI="databricks --profile $PROFILE"

echo ""
echo "▶  AI Genie Factory — Databricks Deploy"
echo "   Profile : $PROFILE"
echo "   Target  : $TARGET_BASE"
echo ""

# ── Helper ────────────────────────────────────────────────────────────────────
upload_file() {
  local local_path="$1"
  local remote_path="$2"
  $CLI workspace import "$remote_path" \
    --file "$local_path" \
    --format RAW \
    --overwrite
  echo "  ✓  $(basename "$remote_path")"
}

# ── 1. Instructions (AGENTS.md → instructions.md) ─────────────────────────────
echo "── Step 1: Upload AGENTS.md as instructions.md ──"
$CLI workspace mkdirs "$TARGET_BASE" 2>/dev/null || true
upload_file "AGENTS.md" "$INSTRUCTIONS_TARGET"
echo ""

# ── 2. Skills ─────────────────────────────────────────────────────────────────
echo "── Step 2: Upload skills ──"
$CLI workspace mkdirs "$SKILLS_TARGET" 2>/dev/null || true

for skill_file in skills/*.md; do
  [[ -f "$skill_file" ]] || continue
  skill_name=$(basename "$skill_file" .md)
  upload_file "$skill_file" "${SKILLS_TARGET}/${skill_name}.md"
done

echo ""
echo "✅  Deploy complete."
echo ""
echo "   Next steps:"
echo "   1. Open Genie Code in Databricks (sparkle icon, top-right)"
echo "   2. Click ⚙️ → User instructions → the file should already be loaded"
echo "   3. In Agent mode, @mention skills by name:"
echo "      @ui-ux-patterns  @databricks-app  @databricks-dashboard"
echo "      @dlt-pipeline  @data-access  @testing-scaffold"
echo ""
