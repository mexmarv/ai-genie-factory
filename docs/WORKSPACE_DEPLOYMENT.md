# Workspace Deployment and Enforcement

How `AGENTS.md` and `skills/` actually reach every user in the workspace, and what
"enforced" does and does not mean.

---

## What Genie Code enforces automatically

Per Databricks' Agent Skills and custom-instructions model (2026):

| Artifact | Path | Who can write it | Applies to |
|---|---|---|---|
| Workspace instructions | `/Workspace/.assistant_workspace_instructions.md` | Workspace admins only | Every user, every session |
| Personal instructions | `/Users/<email>/.assistant_instructions.md` | The user themselves | That user only |
| Workspace skills | `/Workspace/.assistant/skills/<name>/SKILL.md` | Workspace admins (can grant others write access to the folder) | Every user, every session |
| Personal skills | `/Users/<email>/.assistant/skills/<name>/SKILL.md` | The user themselves | That user only |

Genie Code prioritizes workspace instructions over personal ones, and workspace skills are
available to everyone with no per-user setup. Running `./deploy.sh --workspace` (as a
workspace admin) is what makes `AGENTS.md` and every `skills/<name>/SKILL.md` apply to the
whole workspace — that single deploy step is the actual enforcement mechanism, not a policy
declared in this repo.

Instructions are capped at 20,000 characters; content past that limit is silently ignored.
`deploy.sh` checks this before uploading.

---

## What this does NOT enforce

Custom instructions and skills are guidance the assistant reads before generating code — they
are not a runtime guardrail. Genie Code can still be asked to ignore them, and nothing here
stops a user from hand-writing code that violates every rule in `AGENTS.md`. Treat this layer
as "make the right thing the easy, default thing to generate," not as a compliance control.

The real enforcement boundary is the platform itself:

- **Unity Catalog grants** — the only thing that actually blocks a Bronze/Silver read or a
  cross-catalog query, regardless of what an app's source code says.
- **Service-principal permissions** on Databricks Apps — least-privilege grants are what stop
  an app from reading data it shouldn't, not the `@data-access` skill's checklist.
- **Compute policies** — control which cluster/warehouse types are available; use them if
  `spark.table()` inside a Databricks App needs to be structurally impossible, not just
  discouraged.
- **CI checks** (lint rules, table-name regex checks, forbidden-import checks) — the only way
  to catch a violation before it merges, if that level of enforcement is required.

If a rule in `GLOBAL_RULES.md` must never be violated under any circumstance, back it with one
of the controls above, not only with instructions/skills text.

---

## Redeploying after edits

Workspace skills and instructions are read at the start of each new Genie Code session — no
workspace restart is required, but users mid-session need to start a new chat to pick up a
changed skill.

```bash
python3 build_agents.py   # after editing GLOBAL_RULES.md, STACK.md, or modules/*.md
./deploy.sh --workspace   # re-upload AGENTS.md and every skills/<name>/SKILL.md
```
