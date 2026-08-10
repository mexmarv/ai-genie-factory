---
name: databricks-dashboard-colors
description: >
  Color, typography, and theme tokens for native Databricks AI/BI (Lakeview) Dashboards at
  Alpura — distinct from @ui-ux-patterns, which covers Python/Plotly Databricks Apps. Load
  when building, reviewing, or theming any Lakeview Dashboard's canvas, widgets, counter
  tiles, or chart palette, or when the user asks to set up the workspace AI/BI theme, apply
  dark/light dashboard colors, or make dashboards consistent across the workspace. Tokens are
  extracted from Alpura's production "Dashboard General de Ventas Brutas" dashboard and
  provided as both `alpura-dashboard-dark` (source) and `alpura-dashboard-light` (derived).
  Always pair with @databricks-dashboard for dataset SQL, widgets, and layout.
---

# AI/BI Dashboard Theme — Alpura

Native Lakeview Dashboards render through Databricks' own theme engine, not Plotly/Dash CSS.
Do not reuse `@ui-ux-patterns`' Python `SHADOW`/`CARD_STYLE` dicts here — they don't apply to
Lakeview widgets. Use this skill's tokens in the dashboard's own **Settings** panel instead.

Provenance: every hex below was read directly from the rendered
`Dashboard General de Ventas Brutas` production dashboard (computed styles + chart fills),
not invented. Treat it as the reference "good" Alpura dashboard palette — apply it to new
dashboards rather than picking new colors per dashboard.

---

## Where this actually gets enforced

Lakeview dashboards have a real workspace-wide theme, independent of the Genie Code
instructions/skills covered by `@databricks-app`:

- **Workspace-wide (admin, applies to every dashboard by default):**
  Account/workspace **Settings → Appearance → AI/BI → Theme**. Set canvas colors for light
  *and* dark mode, the categorical/visualization palette, fonts, and title alignment once —
  every new dashboard inherits it, and existing dashboards can "apply workspace theme" to pick
  it up. This is also reachable via the Settings API for scripted rollout.
- **Per-dashboard override:** open the draft dashboard → click empty canvas (no widget
  selected) → right panel → **Settings** → **Theme**. The same panel has **Light mode** /
  **Dark mode** toggles to preview and set both variants together.

Set the values below at the workspace level first. Only override per-dashboard when a
dashboard has a real reason to diverge (e.g. an embedded exec-only dashboard).

---

## Theme contract

Every dashboard must support both `alpura-dashboard-dark` (default) and
`alpura-dashboard-light`. The categorical/visualization palette does not change between
modes — only canvas, widget, border, and text tokens do. Never hand-pick a one-off color in
a widget; set it at the theme level so every dashboard stays consistent.

| Setting (Lakeview Theme panel) | `alpura-dashboard-dark` | `alpura-dashboard-light` |
|---|---:|---:|
| Canvas background | `#12181d` | `#f4f7fb` |
| Widget background | `#12181d` (seamless — no elevated cards) | `#ffffff` |
| Widget border | `#1e2a3a` | `#d7e0ea` |
| Axis / grid color | `#253040` | `#c2ceda` |
| Font — Title | `#eef1f5` | `#0d1b2a` |
| Font — Default (labels, axis, filters) | `#8b96a8` | `#40566f` |
| Font — Field value (counter/KPI numbers) | `#e6edf3` | `#0d1b2a` |
| Delta — negative | `#f85149` | `#c32645` |
| Delta — neutral/positive pill | bg `#242a31`, text `#d1d4d8` | bg `#edf4fa`, text `#40566f` |
| Primary series (this period) | `#00bcd4` | `#007a8a` |
| Comparison series (prior period/year) | `#7c4dff` | `#5b32d6` |

Widgets sit flush with the canvas in dark mode (no card elevation) — thin borders are the
only separator. In light mode, give widgets a white card against the light canvas so they
stay legible; this is the one structural difference between modes, not just a color swap.

### Delta color policy

This dashboard does **not** auto-color every positive delta green. Positive/expected
movement renders as a neutral gray pill (`Delta — neutral/positive pill` above) with an
up-arrow glyph; only genuinely negative or below-target values get the red treatment. This
reserves color for the exception, not the default case — carry this policy into every new
dashboard rather than wiring green/red to the sign of every delta.

---

## Visualization palette (categorical + sequential)

One ordered list, set once in **Categorical Colors** in the Theme panel. Used both for
category legends (assign in order) and as a sequential ramp for ranked/ordered data (top-to-
bottom or left-to-right). Identical in light and dark mode.

```
DASHBOARD_PALETTE = [
    "#00bcd4",  # 1 — primary / first category
    "#0b4b60",  # 2
    "#1a6892",  # 3
    "#4d8cc0",  # 4
    "#9580ce",  # 5
    "#cc90c2",  # 6
    "#eab0d0",  # 7
    "#f8dae8",  # 8 — palest, last category
]
```

- Assign categories in this exact order — do not re-sort by value or alphabetically.
- With more than 8 categories, group the smallest into "Otros" before letting the palette
  cycle; a repeated color reads as a data error, not as "more of the same."
- On a light canvas, add a thin `1px` stroke (`Widget border` color) between segments of the
  two palest steps (`#eab0d0`, `#f8dae8`) — they lose separation against white without one.
- Primary/comparison series (KPI bars vs. prior-period line) use the dedicated tokens above,
  not palette positions 1–2 — a single metric's own trend should stay cyan/purple regardless
  of how many categories are in the same dashboard's other charts.

---

## Typography

| Role | Family | Weight | Notes |
|---|---|---|---|
| Counter / KPI value | `Space Grotesk` | 700 | Tabular figures, e.g. `$ 117.40M` |
| Dashboard & widget titles | System UI (`Auto` in the Theme panel) | 600 | Don't force a custom family here |
| Labels, axis, filters | System UI (`Auto`) | 400–500 | |

Set **Field value** family to `Space Grotesk` in the Theme panel; leave **Title** and
**Default** on `Auto` so they follow the workspace's system font stack. This mirrors the
production dashboard exactly — do not substitute Inter/DM Sans here even though
`@ui-ux-patterns` uses them for Apps; Lakeview counter tiles read better with Space Grotesk's
geometric numerals at large sizes.

---

## Relationship to @ui-ux-patterns

| | `@ui-ux-patterns` | `@databricks-dashboard-colors` (this skill) |
|---|---|---|
| Surface | Databricks Apps (Dash/Streamlit, Python) | Native AI/BI Lakeview Dashboards |
| Where tokens live | Python dicts / injected CSS | Lakeview Theme panel (UI or Settings API) |
| Font | Inter (body) + DM Sans (titles) | System UI (titles/labels) + Space Grotesk (KPI values) |
| Negative red | `#f43f5e` | `#f85149` |

The two surfaces render through different engines and are allowed to diverge slightly — both
communicate "negative" and "brand cyan/purple" consistently, which is what matters. Never
port Lakeview's exact hexes into a Dash/Streamlit app, or vice versa; use the skill that
matches the surface you're building.

---

## Forbidden

- Setting a widget-level color override for something the workspace theme already defines.
- Auto-coloring every positive delta green — only the negative/exception case gets a status color.
- Reordering or alphabetizing the categorical palette instead of assigning it in list order.
- Reusing `@ui-ux-patterns`' Python style dicts inside a Lakeview dashboard.
- A light-mode dashboard with widgets flush against the canvas — light mode needs the white
  card treatment; only dark mode is seamless.
- Picking a one-off accent color for a single dashboard instead of updating the workspace
  theme so every dashboard stays consistent.
