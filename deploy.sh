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

for skill_dir in skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_target="${SKILLS_TARGET}/${skill_name}"

  $CLI workspace mkdirs "$skill_target" 2>/dev/null || true
  echo "  [$skill_name]"

  # Upload SKILL.md
  if [[ -f "${skill_dir}SKILL.md" ]]; then
    upload_file "${skill_dir}SKILL.md" "${skill_target}/SKILL.md"
  fi

  # Upload files in references/ subdirectory (if present)
  if [[ -d "${skill_dir}references" ]]; then
    refs_target="${skill_target}/references"
    $CLI workspace mkdirs "$refs_target" 2>/dev/null || true
    for ref_file in "${skill_dir}references/"*.md; do
      [[ -f "$ref_file" ]] || continue
      upload_file "$ref_file" "${refs_target}/$(basename "$ref_file")"
    done
  fi
done

echo ""
echo "✅  Deploy complete."
echo ""
echo "   Next steps:"
echo "   1. Open Genie Code in Databricks (sparkle icon, top-right)"
echo "   2. Click ⚙️ → User instructions → the file should already be loaded"
echo "   3. In Agent mode, @mention skills by name:"
echo "      @databricks-app-design  @data-access  @dlt-pipeline"
echo "      @ui-patterns  @testing-scaffold"
echo ""
