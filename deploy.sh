#!/usr/bin/env bash
# Deploy AI Genie Factory instructions and Agent Skills to Databricks Genie Code.
#
# Workspace-wide (workspace admin):
#   ./deploy.sh --workspace --profile DEFAULT
#
# Personal (the user is resolved from the authenticated CLI identity):
#   ./deploy.sh --profile DEFAULT
#   ./deploy.sh --profile DEFAULT --user user@example.com

set -euo pipefail

PROFILE="DEFAULT"
SCOPE="personal"
USERNAME=""
DRY_RUN="false"

usage() {
  echo "Usage: $0 [--workspace] [--profile NAME] [--user EMAIL] [--dry-run]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      SCOPE="workspace"
      shift
      ;;
    --profile)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
    --user)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      USERNAME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

DBX=(databricks --profile "$PROFILE")

if [[ "$SCOPE" == "workspace" ]]; then
  BASE="/Workspace/.assistant"
  INSTRUCTIONS_TARGET="/Workspace/.assistant_workspace_instructions.md"
else
  if [[ -z "$USERNAME" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      USERNAME="<authenticated-user>"
    else
      USERNAME="$("${DBX[@]}" current-user me -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["userName"])')"
    fi
  fi
  BASE="/Users/${USERNAME}/.assistant"
  INSTRUCTIONS_TARGET="/Users/${USERNAME}/.assistant_instructions.md"
fi

SKILLS_TARGET="${BASE}/skills"

if [[ ! -f AGENTS.md ]]; then
  echo "AGENTS.md not found. Run this script from the repository root." >&2
  exit 1
fi

instruction_chars="$(wc -m < AGENTS.md | tr -d ' ')"
if (( instruction_chars > 20000 )); then
  echo "AGENTS.md has ${instruction_chars} characters; Genie Code only reads the first 20,000." >&2
  exit 1
fi

skill_count=0
for skill_file in skills/*/SKILL.md; do
  [[ -f "$skill_file" ]] || continue
  skill_count=$((skill_count + 1))
done

if (( skill_count == 0 )); then
  echo "No valid skills found. Expected skills/<name>/SKILL.md." >&2
  exit 1
fi

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'DRY RUN:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

upload_raw() {
  local source="$1"
  local target="$2"
  run "${DBX[@]}" workspace import "$target" \
    --file "$source" \
    --format RAW \
    --overwrite
}

echo "AI Genie Factory — Databricks deployment"
echo "Profile: ${PROFILE}"
echo "Scope: ${SCOPE}"
echo "Instructions: ${INSTRUCTIONS_TARGET}"
echo "Skills: ${SKILLS_TARGET}/<name>/SKILL.md"

run "${DBX[@]}" workspace mkdirs "$BASE"
upload_raw "AGENTS.md" "$INSTRUCTIONS_TARGET"

run "${DBX[@]}" workspace mkdirs "$SKILLS_TARGET"
for skill_file in skills/*/SKILL.md; do
  [[ -f "$skill_file" ]] || continue
  skill_name="$(basename "$(dirname "$skill_file")")"
  remote_dir="${SKILLS_TARGET}/${skill_name}"
  run "${DBX[@]}" workspace mkdirs "$remote_dir"
  upload_raw "$skill_file" "${remote_dir}/SKILL.md"
done

echo "Deployment complete. Start a new Genie Code chat to load changed skills."
if [[ "$SCOPE" == "workspace" ]]; then
  echo "Admin follow-up: restrict write access on /Workspace/.assistant and the workspace instructions file."
fi
