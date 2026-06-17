---
name: memory-layer
description: >
  Persistent memory for Genie Code sessions using RAG + RLM (Recursive Language Modeling).
  Load when building apps that need cross-session context: user preferences, past decisions,
  learned patterns, or conversation history. Adds a fourth layer to the factory architecture
  that survives restarts and learns over time.
  
  Use when: "remember this", "what did we decide", "learn from this pattern", "why did we
  choose X", or when apps need to recall past behavior, preferences, or configuration.
  
  Key capability: Combines semantic retrieval (RAG) with pattern distillation (RLM) to
  surface both specific memories and high-confidence learned patterns.
---

# Memory Layer — Cross-Session Persistence for AI Genie Factory

Extends the factory architecture with persistent memory that survives session restarts
and learns patterns over time.

> Contributed by [ThinkCreate.AI](https://thinkcreateai.com)
> Based on the RAG + RLM architecture from [soul.py](https://github.com/menonpg/soul.py)

---

## Table of Contents

1. [Why Memory Matters](#why-memory-matters)
2. [Architecture Overview](#architecture-overview)
3. [Memory Types](#memory-types)
4. [Storage Options](#storage-options)
5. [RAG + RLM Hybrid Architecture](#rag--rlm-hybrid-architecture)
6. [Implementation Guide](#implementation-guide)
7. [Memory Commands](#memory-commands)
8. [Integration with Factory Workflow](#integration-with-factory-workflow)
9. [Production Patterns](#production-patterns)
10. [Testing](#testing)
11. [Troubleshooting](#troubleshooting)

---

## Why Memory Matters

The factory produces consistent apps because constraints are explicit. But Genie Code forgets
everything between sessions:

| What's Lost | Impact |
|-------------|--------|
| Decisions made during development | Developers rediscover the same tradeoffs |
| Preferences discovered through iteration | Every app reinvents team conventions |
| Patterns that worked well | Good solutions don't propagate |
| Context from past conversations | "Why did we do it this way?" has no answer |

Memory closes this gap. It's the difference between an AI that helps and an AI that **learns**.

### The Compounding Effect

```
Session 1: "Use treemaps for budget breakdowns" → logged
Session 2: "Finance wants Excel export" → logged  
Session 3: "Dark theme for ops dashboards" → logged
...
Session 90: New developer asks "build a finance dashboard"
            → Memory surfaces all relevant patterns automatically
```

Without memory, Session 90 starts from scratch. With memory, it inherits 89 sessions of learning.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI Genie Factory Stack                        │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: AGENTS.md                                              │
│           Constitution — immutable, organization-wide            │
│           "Always use three-part table names"                    │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: skills/                                                │
│           Domain Knowledge — loaded on demand                    │
│           @databricks-app, @ui-ux-patterns, @dlt-pipeline        │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3: memory/                          ◄── NEW               │
│           Learned Knowledge — grows over time                    │
│           decisions, preferences, patterns, context              │
├─────────────────────────────────────────────────────────────────┤
│  Layer 4: APP.md                                                 │
│           App-Specific — unique to this task                     │
│           Tables, filters, business requirements                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** Memory never overrides AGENTS.md. It adds context *within* the constraints.

---

## Memory Types

### 1. Decisions — Architectural Choices

Records the "what" and "why" of technical decisions.

```markdown
# decisions.md

## 2026-06-15: Chart Type for Budget Breakdowns
- **Decision:** Use Plotly treemaps instead of pie charts
- **Rationale:** Pie charts don't scale beyond 5-6 categories; treemaps handle
  hierarchical data with 50+ nodes while remaining readable
- **Alternatives considered:** Sunburst (too complex), bar charts (loses hierarchy)
- **Applies to:** All Finance department apps with categorical breakdowns
- **Validation:** Used successfully in DBU Spend Monitor v2 (shipped 2026-06-18)
- **Confidence:** 0.95

## 2026-06-10: Retry Strategy for Warehouse Cold Starts
- **Decision:** Exponential backoff with max 3 retries, base delay 2s
- **Rationale:** Linear retry (fixed 5s) caused thundering herd during morning peak;
  exponential backoff (2s, 4s, 8s) spreads load and succeeds within SLA
- **Alternatives considered:** Circuit breaker (overkill for cold start), no retry (poor UX)
- **Applies to:** All apps using @data-access skill
- **Code pattern:** See patterns.md#warehouse-retry
- **Confidence:** 0.92
```

### 2. Preferences — Team/User Conventions

Captures implicit knowledge that teams accumulate.

```markdown
# preferences.md

## Operations Team
- **Theme:** Dark (#0d1117 background, #c9d1d9 text) — reduces eye strain in NOC
- **Refresh interval:** 30s for real-time monitoring, 5min for shift reports
- **Alert display:** Inline on charts with threshold lines, not separate alert panel
- **Mobile:** Not required — ops uses wall-mounted displays
- **Validated by:** Maria Chen (Ops Lead), 2026-06-12

## Finance Team
- **Theme:** Light — required for print-to-PDF reports
- **Export:** Excel button required on all data tables (Sarah's request, 2026-05-20)
- **Currency format:** $X,XXX.XX for values < $1000, $X,XXX for larger amounts
- **Decimal precision:** 2 places for percentages, 0 for counts
- **Validated by:** James Wilson (Finance Director), 2026-06-08

## Sales Team
- **Layout:** Mobile-first — field reps access from phones 80% of the time
- **Navigation:** Maximum 2 taps to any data point (Carlos's requirement)
- **Gamification:** Leaderboards must show movement arrows (↑↓) not just rank
- **Refresh:** Pull-to-refresh gesture required on mobile
- **Validated by:** Carlos Mendez (VP Sales), 2026-06-01
```

### 3. Patterns — Reusable Code

Proven solutions that should be reused.

```markdown
# patterns.md

## warehouse-retry

Exponential backoff for SQL warehouse cold starts. Handles the 15-30s startup
delay without overwhelming the warehouse or degrading user experience.

**When to use:** Any data.py that queries a serverless SQL warehouse

**Implementation:**

```python
# _retry.py — add to app root alongside _logger.py

import time
from functools import wraps
from typing import TypeVar, Callable, Any
from _logger import get_logger

logger = get_logger(__name__)

T = TypeVar('T')

class RetryExhaustedError(Exception):
    """Raised when all retry attempts fail."""
    pass

def with_retry(
    max_attempts: int = 3,
    base_delay: float = 2.0,
    max_delay: float = 30.0,
    exponential_base: float = 2.0,
    retryable_exceptions: tuple = (Exception,),
) -> Callable[[Callable[..., T]], Callable[..., T]]:
    """
    Decorator for exponential backoff retry.
    
    Args:
        max_attempts: Maximum number of attempts (default: 3)
        base_delay: Initial delay in seconds (default: 2.0)
        max_delay: Maximum delay cap in seconds (default: 30.0)
        exponential_base: Multiplier for each retry (default: 2.0)
        retryable_exceptions: Tuple of exceptions to retry on
    
    Example:
        @with_retry(max_attempts=3, base_delay=2.0)
        def query_warehouse(sql: str) -> pd.DataFrame:
            return execute_sql(sql)
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            last_exception = None
            
            for attempt in range(1, max_attempts + 1):
                try:
                    return func(*args, **kwargs)
                except retryable_exceptions as e:
                    last_exception = e
                    
                    if attempt == max_attempts:
                        logger.error(
                            f"{func.__name__} failed after {max_attempts} attempts: {e}"
                        )
                        raise RetryExhaustedError(
                            f"All {max_attempts} attempts failed for {func.__name__}"
                        ) from e
                    
                    delay = min(base_delay * (exponential_base ** (attempt - 1)), max_delay)
                    logger.warning(
                        f"{func.__name__} attempt {attempt}/{max_attempts} failed: {e}. "
                        f"Retrying in {delay:.1f}s..."
                    )
                    time.sleep(delay)
            
            # Should never reach here, but satisfies type checker
            raise last_exception  # type: ignore
        
        return wrapper
    return decorator
```

**Usage in data.py:**

```python
from _retry import with_retry, RetryExhaustedError

@with_retry(max_attempts=3, base_delay=2.0)
def load_orders(warehouse_id: str, start_date: str) -> pd.DataFrame:
    """Load orders with automatic retry on warehouse cold start."""
    return _execute_sql(
        f"SELECT * FROM gold.sales.orders WHERE order_date >= '{start_date}'",
        warehouse_id
    )
```

**Metrics:**
- Used in: 34 apps (Inventory, Fleet Tracker, DBU Monitor, ...)
- Success rate: 99.7% (warehouse cold starts recovered within 3 attempts)
- Added: 2026-06-10
- Last validated: 2026-06-16
- Confidence: 0.95

---

## kpi-card-with-delta

Standard KPI card showing current value + change from prior period.
Consistent styling across all dashboards.

**When to use:** Any KPI display that needs period-over-period comparison

**Implementation:**

```python
# ui.py — KPI card component

import plotly.graph_objects as go
from dash import html
from typing import Optional

# Design tokens (from @ui-ux-patterns)
CARD_BG = "#161b22"
TEXT_PRIMARY = "#c9d1d9"
TEXT_SECONDARY = "#8b949e"
POSITIVE = "#00c853"
NEGATIVE = "#ff5252"
NEUTRAL = "#8b949e"

def build_kpi_card(
    title: str,
    current: float,
    previous: float,
    fmt: str = "${:,.0f}",
    subtitle: Optional[str] = None,
) -> html.Div:
    """
    Build a KPI card with current value and delta indicator.
    
    Args:
        title: Card title (e.g., "Total Revenue")
        current: Current period value
        previous: Prior period value for comparison
        fmt: Format string for values (default: currency with no decimals)
        subtitle: Optional subtitle (e.g., "vs Last Month")
    
    Returns:
        Dash html.Div component
    """
    # Calculate delta
    delta = current - previous
    delta_pct = (delta / previous * 100) if previous != 0 else 0
    
    # Determine direction and color
    if delta > 0:
        arrow, color = "↑", POSITIVE
    elif delta < 0:
        arrow, color = "↓", NEGATIVE
    else:
        arrow, color = "→", NEUTRAL
    
    return html.Div(
        className="kpi-card",
        style={
            "backgroundColor": CARD_BG,
            "borderRadius": "8px",
            "padding": "20px",
            "boxShadow": "0 4px 6px rgba(0, 0, 0, 0.3)",
        },
        children=[
            html.H4(
                title,
                style={"color": TEXT_SECONDARY, "margin": "0 0 8px 0", "fontSize": "14px"}
            ),
            html.Div(
                fmt.format(current),
                style={"color": TEXT_PRIMARY, "fontSize": "32px", "fontWeight": "600"}
            ),
            html.Div(
                f"{arrow} {abs(delta_pct):.1f}%",
                style={"color": color, "fontSize": "14px", "marginTop": "4px"}
            ),
            html.Div(
                subtitle or "",
                style={"color": TEXT_SECONDARY, "fontSize": "12px", "marginTop": "4px"}
            ) if subtitle else None,
        ],
    )
```

**Metrics:**
- Used in: 52 apps (all Finance and Sales dashboards)
- Added: 2026-06-08
- Last validated: 2026-06-17
- Confidence: 0.98
```

### 4. Context — Active Project State

Current work in progress, pending decisions, recent conversations.

```markdown
# context.md

## Active Sprint: June 15-28, 2026

### Primary Focus
Building regional sales dashboard for LATAM expansion

### Key Requirements
- Support 3 new currencies: BRL (Brazilian Real), ARS (Argentine Peso), CLP (Chilean Peso)
- Handle Argentina's parallel exchange rate situation (official vs. "blue" rate)
- Mobile-first design for field sales team
- PM: Sofia Garcia, stakeholder reviews every Thursday 2pm CT

### Pending Decisions
- [ ] Real-time FX rates vs. daily snapshot? (Decision due: June 20)
  - Pro real-time: More accurate for large deals
  - Pro daily: Simpler, avoids rate API costs
  - Sofia leans toward daily with manual override option

- [ ] How to display Argentina's dual exchange rates?
  - Option A: Show both with toggle
  - Option B: Default to official, footnote blue rate
  - Waiting for legal guidance

### Recent Decisions
- 2026-06-16: Caching strategy decided — Redis for FX rates, 5min TTL
- 2026-06-14: Mobile wireframes approved by Carlos
- 2026-06-12: Chose Plotly treemap for territory breakdown (over sunburst)

### Blockers
- None currently

### Next Actions
1. Implement currency selector component (assigned: self)
2. Set up Redis cache for FX rates (assigned: DevOps, ETA June 19)
3. Schedule legal review for Argentina rates (Sofia to arrange)
```

---

## Storage Options

### Option 1: Workspace Files (Simple Start)

Best for: Small teams, getting started quickly, Git-versioned memory.

```
Workspace/.assistant/
├── instructions.md          # AGENTS.md content
├── skills/
│   ├── databricks-app.md
│   ├── ui-ux-patterns.md
│   └── memory-layer.md      # This skill
└── memory/
    ├── decisions.md
    ├── preferences.md
    ├── patterns.md
    └── context.md
```

**Setup:**

```bash
# Create memory folder
databricks workspace mkdirs /Workspace/.assistant/memory

# Initialize with templates
databricks workspace import /Workspace/.assistant/memory/decisions.md \
  --format SOURCE --language MARKDOWN --content "# Architectural Decisions\n"

databricks workspace import /Workspace/.assistant/memory/preferences.md \
  --format SOURCE --language MARKDOWN --content "# Team Preferences\n"

databricks workspace import /Workspace/.assistant/memory/patterns.md \
  --format SOURCE --language MARKDOWN --content "# Proven Patterns\n"

databricks workspace import /Workspace/.assistant/memory/context.md \
  --format SOURCE --language MARKDOWN --content "# Active Context\n"
```

**Pros:** Simple, version-controlled, human-readable, no infrastructure  
**Cons:** No semantic search, manual updates, doesn't scale past ~100 memories

---

### Option 2: Unity Catalog Tables (Structured Queries)

Best for: Medium teams, queryable history, lineage tracking.

```sql
-- Create memory schema
CREATE SCHEMA IF NOT EXISTS factory.memory
COMMENT 'AI Genie Factory memory layer';

-- Decisions table
CREATE TABLE IF NOT EXISTS factory.memory.decisions (
    id STRING NOT NULL COMMENT 'Unique decision ID (UUID)',
    timestamp TIMESTAMP NOT NULL COMMENT 'When decision was made',
    title STRING NOT NULL COMMENT 'Short decision title',
    decision STRING NOT NULL COMMENT 'The actual decision',
    rationale STRING COMMENT 'Why this decision was made',
    alternatives STRING COMMENT 'Other options considered',
    applies_to ARRAY<STRING> COMMENT 'Apps/teams this applies to',
    confidence DOUBLE COMMENT 'Confidence score 0.0-1.0',
    validated_by STRING COMMENT 'Who validated this decision',
    validated_at TIMESTAMP COMMENT 'When it was last validated',
    references ARRAY<STRING> COMMENT 'Related pattern/decision IDs',
    
    CONSTRAINT decisions_pk PRIMARY KEY (id)
)
USING DELTA
COMMENT 'Architectural decisions with rationale and validation status';

-- Preferences table  
CREATE TABLE IF NOT EXISTS factory.memory.preferences (
    id STRING NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    team STRING NOT NULL COMMENT 'Team name (Ops, Finance, Sales, etc.)',
    category STRING NOT NULL COMMENT 'Preference category (theme, layout, etc.)',
    preference STRING NOT NULL COMMENT 'The actual preference',
    validated_by STRING,
    validated_at TIMESTAMP,
    confidence DOUBLE,
    
    CONSTRAINT preferences_pk PRIMARY KEY (id)
)
USING DELTA
COMMENT 'Team and user preferences discovered through iteration';

-- Patterns table
CREATE TABLE IF NOT EXISTS factory.memory.patterns (
    id STRING NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    name STRING NOT NULL COMMENT 'Pattern name (e.g., warehouse-retry)',
    description STRING NOT NULL COMMENT 'When and why to use this pattern',
    code STRING NOT NULL COMMENT 'The actual code implementation',
    language STRING DEFAULT 'python' COMMENT 'Programming language',
    used_in ARRAY<STRING> COMMENT 'Apps using this pattern',
    usage_count INT DEFAULT 0 COMMENT 'Number of times used',
    success_rate DOUBLE COMMENT 'Success rate when used',
    confidence DOUBLE,
    last_validated TIMESTAMP,
    
    CONSTRAINT patterns_pk PRIMARY KEY (id)
)
USING DELTA
COMMENT 'Reusable code patterns that have proven successful';

-- Context table (current state, frequently updated)
CREATE TABLE IF NOT EXISTS factory.memory.context (
    id STRING NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    context_type STRING NOT NULL COMMENT 'sprint, decision, blocker, action',
    content STRING NOT NULL,
    status STRING DEFAULT 'active' COMMENT 'active, resolved, archived',
    related_to ARRAY<STRING> COMMENT 'Related context IDs',
    
    CONSTRAINT context_pk PRIMARY KEY (id)
)
USING DELTA
TBLPROPERTIES (delta.enableChangeDataFeed = true)
COMMENT 'Active project context, pending decisions, recent conversations';
```

**Pros:** Queryable, lineage tracked, access controlled, audit trail  
**Cons:** No semantic search, requires SQL for retrieval

---

### Option 3: RAG + RLM Hybrid (Recommended for Scale)

Best for: Large teams, 50+ apps, need semantic search and pattern learning.

This is the architecture from [soul.py](https://github.com/menonpg/soul.py) — combining
Retrieval-Augmented Generation (RAG) with Recursive Language Modeling (RLM).

#### Why RAG Alone Isn't Enough

RAG finds semantically similar memories:
- Query: "what chart for budget data?"
- Returns: Past discussions mentioning budgets, charts, data visualization

**Limitation:** RAG is stateless. It retrieves but doesn't learn. With 1000 memories about
chart choices, it returns all 1000. The pattern "use treemaps for hierarchical data" is
implicit across many memories but never made explicit.

#### Why RLM Matters

Recursive Language Modeling adds a distillation layer:

1. **Pattern Extraction** — Identifies recurring themes across raw memories
2. **Knowledge Compression** — 47 chart discussions → "treemaps > pie charts for hierarchy"
3. **Confidence Scoring** — Patterns validated by success get higher confidence
4. **Contradiction Detection** — Flags conflicting decisions for human resolution
5. **Temporal Weighting** — Recent patterns rank higher than stale ones

#### The Hybrid Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 Query: "build budget dashboard"                  │
└───────────────────────────────┬─────────────────────────────────┘
                                │
          ┌─────────────────────┴─────────────────────┐
          ▼                                           ▼
┌─────────────────────┐                   ┌─────────────────────┐
│     RAG Layer       │                   │     RLM Layer       │
│   (Vector Store)    │                   │ (Distilled Wisdom)  │
├─────────────────────┤                   ├─────────────────────┤
│ Semantic retrieval  │                   │ Pattern matching    │
│ from raw memories   │                   │ with confidence     │
├─────────────────────┤                   ├─────────────────────┤
│ Returns:            │                   │ Returns:            │
│ • 2026-06-15 budget │                   │ • "Treemaps > pies" │
│   decision (0.92)   │                   │   conf: 0.95        │
│ • 2026-05-20 chart  │                   │ • "Finance wants    │
│   discussion (0.87) │                   │   Excel" conf: 0.91 │
│ • 2026-04-10 viz    │                   │ • "Dark theme for   │
│   preferences (0.81)│                   │   ops" conf: 0.88   │
└─────────────────────┘                   └─────────────────────┘
          │                                           │
          └─────────────────────┬─────────────────────┘
                                ▼
                  ┌─────────────────────────┐
                  │    Merged Context       │
                  │ ─────────────────────── │
                  │ High-confidence patterns│
                  │ + Relevant raw memories │
                  │ + Current sprint context│
                  └─────────────────────────┘
                                │
                                ▼
                  ┌─────────────────────────┐
                  │   Genie Code receives   │
                  │   enriched context for  │
                  │   informed generation   │
                  └─────────────────────────┘
```

---

## Implementation Guide

### Schema Setup

```sql
-- RAG layer: Raw memories with embeddings
CREATE TABLE IF NOT EXISTS factory.memory.raw_memories (
    id STRING NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    memory_type STRING NOT NULL COMMENT 'decision, preference, pattern, context',
    content STRING NOT NULL COMMENT 'The raw memory text',
    metadata MAP<STRING, STRING> COMMENT 'Structured metadata',
    embedding ARRAY<DOUBLE> COMMENT 'Vector embedding for semantic search',
    
    CONSTRAINT raw_memories_pk PRIMARY KEY (id)
)
USING DELTA
COMMENT 'Raw memories for RAG semantic retrieval';

-- Create vector search index
CREATE VECTOR SEARCH INDEX factory_memory_index
ON factory.memory.raw_memories (embedding)
OPTIONS (metric_type = "COSINE");

-- RLM layer: Distilled patterns
CREATE TABLE IF NOT EXISTS factory.memory.distilled_patterns (
    id STRING NOT NULL,
    pattern STRING NOT NULL COMMENT 'The distilled pattern statement',
    topic STRING NOT NULL COMMENT 'Topic category for filtering',
    confidence DOUBLE NOT NULL COMMENT 'Confidence score 0.0-1.0',
    evidence_ids ARRAY<STRING> COMMENT 'Raw memory IDs supporting this pattern',
    evidence_count INT COMMENT 'Number of supporting memories',
    created_at TIMESTAMP NOT NULL,
    last_validated TIMESTAMP,
    validation_count INT DEFAULT 0 COMMENT 'Times this pattern was validated',
    contradiction_flags ARRAY<STRING> COMMENT 'IDs of conflicting patterns',
    
    CONSTRAINT patterns_pk PRIMARY KEY (id)
)
USING DELTA
COMMENT 'Distilled patterns from RLM processing';
```

### Core Memory Module

```python
# memory.py — Memory layer implementation for AI Genie Factory

"""
Memory Layer for AI Genie Factory

Implements RAG + RLM hybrid architecture for persistent, learning memory.
See: https://thinkcreateai.com | https://github.com/menonpg/soul.py

Usage:
    from memory import MemoryLayer
    
    memory = MemoryLayer(catalog="factory", schema="memory")
    
    # Log a new decision
    memory.log_decision(
        title="Chart type for budgets",
        decision="Use treemaps instead of pie charts",
        rationale="Treemaps handle hierarchy better",
        applies_to=["Finance"]
    )
    
    # Recall relevant context
    context = memory.recall("build budget dashboard", topic="visualization")
"""

import uuid
from datetime import datetime, timedelta
from typing import Optional, Any
from dataclasses import dataclass, field

from pyspark.sql import SparkSession
from databricks.vector_search.client import VectorSearchClient
from databricks.sdk import WorkspaceClient

from _logger import get_logger

logger = get_logger(__name__)


@dataclass
class Memory:
    """A single memory entry."""
    id: str
    timestamp: datetime
    memory_type: str  # decision, preference, pattern, context
    content: str
    metadata: dict = field(default_factory=dict)
    confidence: float = 0.5
    

@dataclass
class Pattern:
    """A distilled pattern from RLM."""
    id: str
    pattern: str
    topic: str
    confidence: float
    evidence_count: int
    last_validated: Optional[datetime] = None


@dataclass
class RecallResult:
    """Result of a memory recall operation."""
    raw_memories: list[Memory]      # From RAG
    patterns: list[Pattern]          # From RLM
    context: list[Memory]            # Current sprint/project context
    
    def to_prompt_context(self) -> str:
        """Format for injection into Genie Code prompt."""
        sections = []
        
        if self.patterns:
            sections.append("## Learned Patterns (high confidence)\n")
            for p in sorted(self.patterns, key=lambda x: -x.confidence)[:5]:
                sections.append(f"- {p.pattern} (confidence: {p.confidence:.0%})")
        
        if self.raw_memories:
            sections.append("\n## Relevant Past Decisions\n")
            for m in self.raw_memories[:5]:
                sections.append(f"- [{m.timestamp.strftime('%Y-%m-%d')}] {m.content[:200]}...")
        
        if self.context:
            sections.append("\n## Current Context\n")
            for c in self.context:
                sections.append(f"- {c.content}")
        
        return "\n".join(sections)


class MemoryLayer:
    """
    RAG + RLM memory layer for AI Genie Factory.
    
    Combines semantic retrieval (RAG) with pattern distillation (RLM)
    to provide both specific memories and learned patterns.
    """
    
    def __init__(
        self,
        catalog: str = "factory",
        schema: str = "memory",
        vector_index: str = "factory_memory_index",
        spark: Optional[SparkSession] = None,
    ):
        self.catalog = catalog
        self.schema = schema
        self.vector_index = vector_index
        self.spark = spark or SparkSession.builder.getOrCreate()
        self.vsc = VectorSearchClient()
        
        self._table = lambda name: f"{catalog}.{schema}.{name}"
    
    # ─────────────────────────────────────────────────────────────
    # Logging Methods
    # ─────────────────────────────────────────────────────────────
    
    def log_decision(
        self,
        title: str,
        decision: str,
        rationale: Optional[str] = None,
        alternatives: Optional[str] = None,
        applies_to: Optional[list[str]] = None,
        confidence: float = 0.7,
    ) -> str:
        """
        Log an architectural decision.
        
        Args:
            title: Short decision title
            decision: The actual decision made
            rationale: Why this decision was made
            alternatives: Other options that were considered
            applies_to: List of apps/teams this applies to
            confidence: Initial confidence score (0.0-1.0)
        
        Returns:
            The decision ID
        """
        memory_id = str(uuid.uuid4())
        content = f"**{title}**\n\nDecision: {decision}"
        if rationale:
            content += f"\n\nRationale: {rationale}"
        if alternatives:
            content += f"\n\nAlternatives considered: {alternatives}"
        
        metadata = {
            "title": title,
            "decision": decision,
            "rationale": rationale or "",
            "alternatives": alternatives or "",
            "applies_to": ",".join(applies_to or []),
        }
        
        self._insert_memory(memory_id, "decision", content, metadata, confidence)
        logger.info(f"Logged decision: {title} (id={memory_id})")
        return memory_id
    
    def log_preference(
        self,
        team: str,
        category: str,
        preference: str,
        validated_by: Optional[str] = None,
        confidence: float = 0.7,
    ) -> str:
        """
        Log a team/user preference.
        
        Args:
            team: Team name (Ops, Finance, Sales, etc.)
            category: Preference category (theme, layout, export, etc.)
            preference: The actual preference
            validated_by: Who validated this preference
            confidence: Confidence score (0.0-1.0)
        
        Returns:
            The preference ID
        """
        memory_id = str(uuid.uuid4())
        content = f"[{team}] {category}: {preference}"
        
        metadata = {
            "team": team,
            "category": category,
            "preference": preference,
            "validated_by": validated_by or "",
        }
        
        self._insert_memory(memory_id, "preference", content, metadata, confidence)
        logger.info(f"Logged preference: {team}/{category} (id={memory_id})")
        return memory_id
    
    def log_pattern(
        self,
        name: str,
        description: str,
        code: str,
        language: str = "python",
        used_in: Optional[list[str]] = None,
        confidence: float = 0.7,
    ) -> str:
        """
        Log a reusable code pattern.
        
        Args:
            name: Pattern name (e.g., "warehouse-retry")
            description: When and why to use this pattern
            code: The actual code implementation
            language: Programming language
            used_in: List of apps using this pattern
            confidence: Confidence score (0.0-1.0)
        
        Returns:
            The pattern ID
        """
        memory_id = str(uuid.uuid4())
        content = f"**{name}**\n\n{description}\n\n```{language}\n{code}\n```"
        
        metadata = {
            "name": name,
            "description": description,
            "language": language,
            "used_in": ",".join(used_in or []),
        }
        
        self._insert_memory(memory_id, "pattern", content, metadata, confidence)
        logger.info(f"Logged pattern: {name} (id={memory_id})")
        return memory_id
    
    def log_context(
        self,
        context_type: str,
        content: str,
        status: str = "active",
    ) -> str:
        """
        Log current project context.
        
        Args:
            context_type: Type of context (sprint, decision, blocker, action)
            content: The context content
            status: Status (active, resolved, archived)
        
        Returns:
            The context ID
        """
        memory_id = str(uuid.uuid4())
        
        metadata = {
            "context_type": context_type,
            "status": status,
        }
        
        self._insert_memory(memory_id, "context", content, metadata, confidence=0.9)
        logger.info(f"Logged context: {context_type} (id={memory_id})")
        return memory_id
    
    # ─────────────────────────────────────────────────────────────
    # Recall Methods
    # ─────────────────────────────────────────────────────────────
    
    def recall(
        self,
        query: str,
        topic: Optional[str] = None,
        top_k_raw: int = 5,
        top_k_patterns: int = 5,
        min_confidence: float = 0.6,
        include_context: bool = True,
    ) -> RecallResult:
        """
        Recall relevant memories using RAG + RLM hybrid.
        
        Args:
            query: The query to search for
            topic: Optional topic filter for patterns
            top_k_raw: Number of raw memories to retrieve (RAG)
            top_k_patterns: Number of patterns to retrieve (RLM)
            min_confidence: Minimum confidence threshold for patterns
            include_context: Whether to include active context
        
        Returns:
            RecallResult with raw memories, patterns, and context
        """
        # RAG: Semantic search over raw memories
        raw_memories = self._rag_recall(query, top_k=top_k_raw)
        
        # RLM: Get distilled patterns
        patterns = self._rlm_recall(
            query, topic=topic, top_k=top_k_patterns, min_confidence=min_confidence
        )
        
        # Context: Get active project context
        context = []
        if include_context:
            context = self._get_active_context()
        
        logger.info(
            f"Recalled {len(raw_memories)} memories, "
            f"{len(patterns)} patterns, {len(context)} context items"
        )
        
        return RecallResult(
            raw_memories=raw_memories,
            patterns=patterns,
            context=context,
        )
    
    def _rag_recall(self, query: str, top_k: int = 5) -> list[Memory]:
        """RAG: Semantic search over raw memories."""
        try:
            index = self.vsc.get_index(self.vector_index)
            results = index.similarity_search(
                query_text=query,
                columns=["id", "timestamp", "memory_type", "content", "metadata", "confidence"],
                num_results=top_k,
            )
            
            memories = []
            for row in results.get("result", {}).get("data_array", []):
                memories.append(Memory(
                    id=row[0],
                    timestamp=row[1],
                    memory_type=row[2],
                    content=row[3],
                    metadata=row[4] or {},
                    confidence=row[5] or 0.5,
                ))
            return memories
            
        except Exception as e:
            logger.warning(f"RAG recall failed: {e}")
            return []
    
    def _rlm_recall(
        self,
        query: str,
        topic: Optional[str] = None,
        top_k: int = 5,
        min_confidence: float = 0.6,
    ) -> list[Pattern]:
        """RLM: Get distilled patterns weighted by confidence and recency."""
        try:
            topic_filter = f"AND topic = '{topic}'" if topic else ""
            
            # Score = confidence * recency_factor
            # recency_factor decays from 1.0 to 0.5 over 365 days
            patterns_df = self.spark.sql(f"""
                SELECT 
                    id, pattern, topic, confidence, evidence_count, last_validated,
                    confidence * (1.0 - LEAST(DATEDIFF(CURRENT_DATE, last_validated), 365) / 730.0) AS score
                FROM {self._table('distilled_patterns')}
                WHERE confidence >= {min_confidence}
                {topic_filter}
                ORDER BY score DESC
                LIMIT {top_k}
            """).collect()
            
            return [
                Pattern(
                    id=row.id,
                    pattern=row.pattern,
                    topic=row.topic,
                    confidence=row.confidence,
                    evidence_count=row.evidence_count,
                    last_validated=row.last_validated,
                )
                for row in patterns_df
            ]
            
        except Exception as e:
            logger.warning(f"RLM recall failed: {e}")
            return []
    
    def _get_active_context(self) -> list[Memory]:
        """Get active project context."""
        try:
            context_df = self.spark.sql(f"""
                SELECT id, timestamp, 'context' as memory_type, content, metadata, 0.9 as confidence
                FROM {self._table('context')}
                WHERE status = 'active'
                ORDER BY timestamp DESC
                LIMIT 10
            """).collect()
            
            return [
                Memory(
                    id=row.id,
                    timestamp=row.timestamp,
                    memory_type="context",
                    content=row.content,
                    metadata=row.metadata or {},
                    confidence=0.9,
                )
                for row in context_df
            ]
            
        except Exception as e:
            logger.warning(f"Context retrieval failed: {e}")
            return []
    
    # ─────────────────────────────────────────────────────────────
    # Internal Methods
    # ─────────────────────────────────────────────────────────────
    
    def _insert_memory(
        self,
        memory_id: str,
        memory_type: str,
        content: str,
        metadata: dict,
        confidence: float,
    ) -> None:
        """Insert a memory into the raw memories table."""
        # Generate embedding using Databricks Foundation Models
        embedding = self._generate_embedding(content)
        
        self.spark.sql(f"""
            INSERT INTO {self._table('raw_memories')}
            (id, timestamp, memory_type, content, metadata, confidence, embedding)
            VALUES (
                '{memory_id}',
                CURRENT_TIMESTAMP(),
                '{memory_type}',
                '{content.replace("'", "''")}',
                MAP({self._dict_to_map_args(metadata)}),
                {confidence},
                ARRAY({','.join(str(x) for x in embedding)})
            )
        """)
    
    def _generate_embedding(self, text: str) -> list[float]:
        """Generate embedding using Databricks Foundation Models."""
        try:
            w = WorkspaceClient()
            response = w.serving_endpoints.query(
                name="databricks-bge-large-en",
                inputs=[text]
            )
            return response.predictions[0]
        except Exception as e:
            logger.warning(f"Embedding generation failed: {e}, using zero vector")
            return [0.0] * 1024  # BGE-large dimension
    
    @staticmethod
    def _dict_to_map_args(d: dict) -> str:
        """Convert dict to Spark SQL MAP() arguments."""
        if not d:
            return ""
        pairs = [f"'{k}', '{str(v).replace(chr(39), chr(39)+chr(39))}'" for k, v in d.items()]
        return ", ".join(pairs)


# ─────────────────────────────────────────────────────────────────
# RLM Distillation Job
# ─────────────────────────────────────────────────────────────────

def run_distillation(
    memory: MemoryLayer,
    lookback_days: int = 7,
    min_evidence: int = 3,
) -> int:
    """
    RLM distillation job: Extract patterns from recent raw memories.
    
    Run this daily or weekly to compress raw memories into patterns.
    
    Args:
        memory: MemoryLayer instance
        lookback_days: How many days of memories to analyze
        min_evidence: Minimum memories required to create a pattern
    
    Returns:
        Number of patterns created/updated
    """
    logger.info(f"Starting RLM distillation (lookback={lookback_days} days)")
    
    # Get recent memories
    recent_memories = memory.spark.sql(f"""
        SELECT id, memory_type, content, metadata
        FROM {memory._table('raw_memories')}
        WHERE timestamp > CURRENT_DATE - INTERVAL {lookback_days} DAYS
        ORDER BY timestamp DESC
    """).collect()
    
    if len(recent_memories) < min_evidence:
        logger.info(f"Only {len(recent_memories)} memories, skipping distillation")
        return 0
    
    # Use LLM to extract patterns
    from databricks.sdk import WorkspaceClient
    w = WorkspaceClient()
    
    memory_text = "\n\n".join([
        f"[{row.memory_type}] {row.content}" for row in recent_memories
    ])
    
    prompt = f"""Analyze these {len(recent_memories)} recent memories from an AI coding assistant.
Extract reusable patterns that appear multiple times.

Memories:
{memory_text}

For each pattern found, output in this exact format:
PATTERN: [one-line pattern statement]
TOPIC: [category: visualization, data-access, ui, pipeline, testing, etc.]
CONFIDENCE: [0.0-1.0 based on how consistent the evidence is]
EVIDENCE_COUNT: [number of memories supporting this]
---

Only extract patterns with at least {min_evidence} supporting memories.
Focus on actionable, reusable patterns, not one-off decisions."""

    response = w.serving_endpoints.query(
        name="databricks-meta-llama-3-1-70b-instruct",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=2000,
    )
    
    # Parse and store patterns
    patterns_created = 0
    pattern_text = response.choices[0].message.content
    
    for block in pattern_text.split("---"):
        if "PATTERN:" not in block:
            continue
        
        try:
            lines = block.strip().split("\n")
            pattern_data = {}
            for line in lines:
                if ":" in line:
                    key, value = line.split(":", 1)
                    pattern_data[key.strip()] = value.strip()
            
            if all(k in pattern_data for k in ["PATTERN", "TOPIC", "CONFIDENCE"]):
                pattern_id = str(uuid.uuid4())
                memory.spark.sql(f"""
                    MERGE INTO {memory._table('distilled_patterns')} t
                    USING (SELECT 
                        '{pattern_id}' as id,
                        '{pattern_data['PATTERN'].replace("'", "''")}' as pattern,
                        '{pattern_data['TOPIC']}' as topic,
                        {float(pattern_data['CONFIDENCE'])} as confidence,
                        {int(pattern_data.get('EVIDENCE_COUNT', 3))} as evidence_count,
                        CURRENT_TIMESTAMP() as created_at,
                        CURRENT_TIMESTAMP() as last_validated,
                        1 as validation_count
                    ) s
                    ON t.pattern = s.pattern
                    WHEN MATCHED THEN UPDATE SET
                        t.confidence = (t.confidence + s.confidence) / 2,
                        t.evidence_count = t.evidence_count + s.evidence_count,
                        t.last_validated = s.last_validated,
                        t.validation_count = t.validation_count + 1
                    WHEN NOT MATCHED THEN INSERT *
                """)
                patterns_created += 1
                logger.info(f"Distilled pattern: {pattern_data['PATTERN'][:50]}...")
                
        except Exception as e:
            logger.warning(f"Failed to parse pattern block: {e}")
            continue
    
    logger.info(f"Distillation complete: {patterns_created} patterns created/updated")
    return patterns_created
```

### Distillation Job Setup

```python
# jobs/memory_distillation.py — Schedule as daily Databricks workflow

"""
Daily Memory Distillation Job

Runs RLM to extract patterns from the past week's memories.
Schedule via Databricks Workflows to run daily at 2 AM.
"""

from memory import MemoryLayer, run_distillation

def main():
    memory = MemoryLayer(catalog="factory", schema="memory")
    
    patterns_created = run_distillation(
        memory=memory,
        lookback_days=7,
        min_evidence=3,
    )
    
    print(f"Distillation complete: {patterns_created} patterns")
    return {"patterns_created": patterns_created}

if __name__ == "__main__":
    main()
```

---

## Memory Commands

Use these in Genie Code prompts:

| Command | Effect |
|---------|--------|
| `@memory-layer recall [query]` | RAG + RLM recall for query |
| `@memory-layer recall decisions` | Show recent architectural decisions |
| `@memory-layer recall preferences for [team]` | Show team preferences |
| `@memory-layer recall patterns for [topic]` | Show patterns by topic |
| `@memory-layer log decision: [text]` | Record a new decision |
| `@memory-layer log preference: [text]` | Record a preference |
| `@memory-layer log pattern: [code]` | Record a code pattern |
| `@memory-layer context` | Show active project context |
| `@memory-layer validate [pattern-id]` | Mark pattern as validated |

---

## Integration with Factory Workflow

### Session Startup

```
1. Load AGENTS.md (constitution)
2. Load relevant skills (@databricks-app, @ui-ux-patterns, etc.)
3. @memory-layer recall [current task]
4. Apply merged context to generation
```

### During Generation

When Genie Code makes a decision:

```
@memory-layer log decision: Chose treemap over pie chart for budget breakdown
because pie charts don't scale beyond 5-6 categories and the budget has 20+ line items.
```

### Post-Generation

Memory files updated. Distillation job runs nightly. Next session inherits learning.

---

## Production Patterns

### Pattern: Memory-Aware Prompt Template

Add to `templates/PROMPT_TEMPLATE.md`:

```markdown
## Memory Context

Before generating, recall relevant context:

@memory-layer recall [APP_NAME] [APP_TYPE]
@memory-layer recall preferences for [TEAM]
@memory-layer context

Apply all high-confidence patterns. Reference specific memories when making decisions.
Log any new decisions or discovered preferences.
```

### Pattern: Decision Logging After Generation

Add to your workflow:

```
After completing app generation:
1. Review decisions made during generation
2. @memory-layer log decision: [for each significant decision]
3. @memory-layer log preference: [for any discovered team preferences]
4. @memory-layer log pattern: [for any reusable code worth capturing]
```

### Pattern: Confidence Decay

Patterns that aren't validated decay in confidence over time:

```sql
-- Run monthly to decay unvalidated patterns
UPDATE factory.memory.distilled_patterns
SET confidence = confidence * 0.95
WHERE last_validated < CURRENT_DATE - INTERVAL 30 DAYS
  AND confidence > 0.5;
```

---

## Testing

```python
# tests/test_memory.py

import pytest
from datetime import datetime
from memory import MemoryLayer, Memory, Pattern, RecallResult

class TestMemoryLayer:
    """Tests for Memory Layer implementation."""
    
    @pytest.fixture
    def memory(self, spark_session):
        """Create a test memory layer."""
        return MemoryLayer(
            catalog="test_factory",
            schema="memory",
            spark=spark_session
        )
    
    def test_log_decision(self, memory):
        """Test logging a decision."""
        decision_id = memory.log_decision(
            title="Test Decision",
            decision="Use treemaps for hierarchy",
            rationale="Better than pie charts",
            applies_to=["Finance"],
            confidence=0.9
        )
        
        assert decision_id is not None
        assert len(decision_id) == 36  # UUID length
    
    def test_log_preference(self, memory):
        """Test logging a preference."""
        pref_id = memory.log_preference(
            team="Ops",
            category="theme",
            preference="Dark mode",
            validated_by="Maria Chen",
            confidence=0.85
        )
        
        assert pref_id is not None
    
    def test_recall_returns_result(self, memory):
        """Test that recall returns a RecallResult."""
        result = memory.recall("budget dashboard", topic="visualization")
        
        assert isinstance(result, RecallResult)
        assert hasattr(result, 'raw_memories')
        assert hasattr(result, 'patterns')
        assert hasattr(result, 'context')
    
    def test_recall_result_to_prompt(self, memory):
        """Test formatting recall result for prompt injection."""
        result = RecallResult(
            raw_memories=[
                Memory(
                    id="1", timestamp=datetime.now(),
                    memory_type="decision", content="Use treemaps",
                    metadata={}, confidence=0.9
                )
            ],
            patterns=[
                Pattern(
                    id="1", pattern="Treemaps > pies for hierarchy",
                    topic="visualization", confidence=0.95,
                    evidence_count=5
                )
            ],
            context=[]
        )
        
        prompt_text = result.to_prompt_context()
        
        assert "Learned Patterns" in prompt_text
        assert "Treemaps > pies" in prompt_text
        assert "95%" in prompt_text
```

---

## Troubleshooting

### Memory Not Being Recalled

**Symptom:** `recall()` returns empty results

**Checks:**
1. Vector index exists: `SELECT * FROM factory.memory.raw_memories LIMIT 1`
2. Index is synced: Check Databricks Vector Search UI
3. Embeddings are populated: `SELECT COUNT(*) FROM raw_memories WHERE embedding IS NOT NULL`

### Patterns Have Low Confidence

**Symptom:** Good patterns showing < 0.6 confidence

**Fix:** Run validation more frequently:
```sql
UPDATE factory.memory.distilled_patterns
SET confidence = LEAST(confidence + 0.1, 1.0),
    last_validated = CURRENT_TIMESTAMP(),
    validation_count = validation_count + 1
WHERE id = '[pattern-id]';
```

### Distillation Not Finding Patterns

**Symptom:** `run_distillation()` returns 0 patterns

**Checks:**
1. Enough memories: Need at least `min_evidence` (default 3) for a pattern
2. Recent memories: Check `lookback_days` setting
3. LLM response: Add logging to see raw LLM output

---

## Credits

Memory layer pattern developed by [ThinkCreate.AI](https://thinkcreateai.com).

Based on the RAG + RLM (Recursive Language Modeling) architecture from 
[soul.py](https://github.com/menonpg/soul.py) — a persistent memory system for AI agents
that combines semantic retrieval with pattern distillation.

**Key innovations adapted for the Factory:**
- **Dual-layer recall** — RAG for specifics, RLM for patterns
- **Confidence scoring** — Recent, validated patterns rank higher
- **Distillation jobs** — Compress raw memories into reusable wisdom
- **Contradiction detection** — Flag conflicting decisions for resolution
- **Temporal decay** — Stale patterns lose confidence over time
