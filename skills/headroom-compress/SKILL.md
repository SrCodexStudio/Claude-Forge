---
name: headroom-compress
description: Context compression audit. Detects stale file reads, bloated Bash output, redundant content, and wasted tokens. Produces a compression report with estimated savings and actionable recommendations.
triggers:
  - "headroom"
  - "compress context"
  - "optimize tokens"
  - "context audit"
  - "save tokens"
  - "context is full"
  - "running out of context"
  - "session feels slow"
author: SrCodexStudio
version: 1.0.0
---

# Headroom Context Compression

Audit the current session's context window for waste, bloat, and stale content. Produce a compression report with estimated token savings and concrete actions to reclaim context space. Based on the principle that 40-60% of context in a typical session is stale, redundant, or unnecessarily verbose.

## Activation

Run this skill:
- When the user says "headroom", "compress context", "optimize tokens"
- Before running `/compact` (to decide what to preserve vs. discard)
- When the session feels slow or responses degrade
- Automatically every 20+ tool calls (silent mode)
- When Bash output exceeds 3000 tokens

## Audit Categories

### 1. Stale Reads (Target: 67% of all Read output)

A Read becomes stale when the file it loaded was subsequently edited. The old content is wrong and occupies context for nothing.

```
DETECTION:
  For each Read tool call in the session:
    1. Record the file path and the turn number
    2. Check if an Edit or Write was applied to that file AFTER the Read
    3. If yes: the Read is STALE (content in context is outdated)
    4. If the file was Read twice: only the LATEST Read matters, earlier ones are SUPERSEDED

CLASSIFICATION:
  STALE (67%):      File was Read then later Edited -- content is WRONG
  SUPERSEDED (12%): File was Read twice -- only latest matters
  FRESH (20%):      Untouched since Read -- must preserve

ESTIMATED SAVINGS:
  stale_reads * avg_tokens_per_read = tokens_recoverable
  Typical Read output: 200-2000 tokens
  Typical session: 10-30 Reads, 67% stale = 1300-40000 tokens wasted
```

### 2. Bash Output Bloat (Target: 70-90% of build/test logs)

Build logs, test output, npm install logs, and git diffs are the largest single source of context waste.

```
DETECTION:
  For each Bash tool call in the session:
    1. Measure output length in tokens (approximate: chars / 4)
    2. Classify content type:
       - Build log: keep ONLY errors, warnings (first 5 deduped), final status
       - Test output: keep ONLY failures, summary line
       - npm/pip install: keep ONLY errors, final success/fail
       - git diff: keep hunks with changes, skip context-only lines
       - git log: keep commit messages, skip decorations
       - ls/find: already compact, keep as-is
       - Server logs: keep errors, first occurrence of each unique message

COMPRESSION RATIOS BY TYPE:
  Build logs:       keep 10%, discard 90%
  Test results:     keep 15%, discard 85%
  Install output:   keep 5%, discard 95%
  Git diff:         keep 40%, discard 60%
  Search results:   keep 70%, discard 30%
  Server output:    keep 10%, discard 90%
```

### 3. Redundant Content

Content that appears multiple times in the session or restates what is already known.

```
DETECTION:
  - Same file Read multiple times (superseded reads)
  - Same Grep pattern run twice with same results
  - Assistant echoing user's question before answering
  - Assistant restating code that was just shown
  - Multiple failed attempts at the same command (keep only last success)
  - Preambles: "Let me think about this...", "I'll now...", "Sure, I can help..."
  - Closing fluff: "Let me know if you need anything else!"
```

### 4. Reference Data Integrity Check

Some tool outputs must NEVER be compressed because editing tools depend on exact string matching.

```
PROTECTED (never compress):
  - Read output for files that have NOT been edited (needed for Edit old_string matching)
  - Glob output (already compact file paths)
  - Grep output with exact matches (needed for navigation)
  - Write/Edit confirmations (records of what changed)

TARGET FOR COMPRESSION:
  - Bash output (primary target)
  - Stale Read output (files already edited)
  - Superseded Read output (re-read files)
  - Assistant verbosity (echoing, preambles, fluff)
```

## Execution Procedure

```
STEP 1: INVENTORY
  Count all tool calls in the session by type:
    - Read calls: [count], total tokens: [estimate]
    - Bash calls: [count], total tokens: [estimate]
    - Grep calls: [count], total tokens: [estimate]
    - Edit/Write calls: [count]
    - Other calls: [count]

STEP 2: STALE READ ANALYSIS
  For each Read:
    - Was the file subsequently edited? -> STALE
    - Was the file read again later? -> SUPERSEDED
    - Neither? -> FRESH
  Calculate: stale_count, superseded_count, fresh_count
  Calculate: estimated tokens in stale + superseded reads

STEP 3: BASH BLOAT ANALYSIS
  For each Bash output:
    - Classify type (build, test, install, diff, search, other)
    - Measure token count
    - Calculate compressible percentage based on type
  Calculate: total Bash tokens, compressible tokens

STEP 4: REDUNDANCY SCAN
  - Count duplicate file reads
  - Count repeated grep patterns
  - Count assistant echo/preamble instances
  - Estimate tokens in redundant content

STEP 5: GENERATE REPORT
  Combine all findings into the report format below

STEP 6: RECOMMENDATIONS
  Rank actions by tokens recoverable (highest first)
  Provide specific /compact instructions
```

## Report Format

```
========================================
  HEADROOM COMPRESSION REPORT
========================================

Session Stats:
  Total tool calls:     [N]
  Estimated context:    [N]K tokens / 1M available
  Context utilization:  [N]%

WASTE BREAKDOWN:
  Stale reads:          [N] tokens  ([N] files read then edited)
  Superseded reads:     [N] tokens  ([N] files read multiple times)
  Bash bloat:           [N] tokens  ([N] verbose outputs)
  Redundancy:           [N] tokens  ([N] duplicate/echo instances)
  ─────────────────────────────────
  TOTAL RECOVERABLE:    [N] tokens  ([N]% of current context)

DETAIL: Stale Reads
  [file_path] -- Read at turn [N], Edited at turn [M] -- ~[N] tokens wasted
  [file_path] -- Read at turn [N], Read again at turn [M] -- ~[N] tokens superseded
  ...

DETAIL: Bash Bloat
  Turn [N]: build log -- [N] tokens, [N]% compressible
  Turn [M]: npm install -- [N] tokens, [N]% compressible
  ...

DETAIL: Redundancy
  [N] assistant preambles detected (~[N] tokens)
  [N] echo-backs of user input detected (~[N] tokens)
  [N] duplicate grep results detected (~[N] tokens)

========================================
  RECOMMENDATIONS (by impact)
========================================

1. [HIGHEST IMPACT] Run /compact preserving: [list of FRESH files and critical decisions]
2. [HIGH IMPACT] Stale reads for [files] are safe to forget
3. [MEDIUM IMPACT] Build logs from turns [N-M] contain only noise
4. [LOW IMPACT] Reduce assistant verbosity for remaining session

OPTIMAL /compact INSTRUCTION:
  /compact Preserve: [critical file list], [key decisions], [current task state]
  Discard: [stale files], [build logs], [redundant content]

========================================
```

## Adaptive Behavior

### Based on Session Length

| Session Length | Strategy | Keep % |
|---|---|---|
| Short (<20 turns) | Light audit, mostly informational | 70% |
| Medium (20-50 turns) | Standard compression | 30% |
| Long (50+ turns) | Aggressive compression | 15% |

### Based on Content Type

| Content | Keep Strategy |
|---|---|
| JSON/arrays | All keys, first 30% + last 15%, errors, anomalies |
| Source code | Imports, signatures, types, decorators, error handlers |
| Build logs | Errors (all), stack traces (max 3), warnings (max 5 deduped) |
| Search results | First/last match per file, max 5 per file, max 30 total |
| Git diffs | Hunks with changes, file paths, stats |
| Prose/text | High-information-density sentences, conclusions |

## Protection Rules

### Last 4 Messages

NEVER suggest compressing the last 4 messages in the conversation. They contain the most recent context and are likely still relevant.

### Small Content

Content under 250 tokens is not worth the overhead of analyzing for compression. Skip it.

### Active Review

If the user is currently reviewing code or analyzing a specific file, that file's Read output is PROTECTED regardless of age.

### Compression Self-Check

If the compression report itself would be longer than the savings it identifies, do not generate it. Simply report: "Context is healthy, no compression needed."

## Silent Mode

When running autonomously (every 20 tool calls), do NOT generate a full report. Instead:

1. Check if any category has significant waste (>5000 tokens recoverable)
2. If yes: flag to user with a one-line summary: "Context audit: ~[N]K tokens recoverable from [N] stale reads and [N] verbose outputs. Run /headroom for full report."
3. If no: do nothing, continue silently
