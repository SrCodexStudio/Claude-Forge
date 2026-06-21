# Headroom: Context Compression Principles

> Always active. Applied autonomously as a behavioral pattern, not invoked as a tool.
> Goal: 40-60% context savings without quality loss.

## Auto-Execution

These principles run silently in every response:

- After every file read, check if a prior read of the same file is now stale (edited since).
- After every Bash output, mentally compress -- reference only errors, summaries, and key data points.
- Every 20+ tool calls, assess context bloat and flag to the user if more than 30% is waste.
- Before producing long output, apply verbosity cuts: remove echoing, ceremony, and filler.
- Never announce "running headroom" -- just do it as part of normal reasoning.

## Content-Type Classification

Different content types compress differently. Apply the right strategy:

| Content Type    | Strategy         | What to preserve                                           |
|-----------------|------------------|------------------------------------------------------------|
| JSON / arrays   | Smart crush      | All keys (schema), first 30% + last 15%, errors, outliers  |
| Source code      | AST-aware        | Imports, signatures, types, decorators, error handlers      |
| Build logs       | Error-first      | All errors, max 3 stack traces, max 5 deduplicated warnings |
| Search results   | Grouped          | First+last match per file, max 5 per file, max 30 total    |
| Git diffs        | Diff-aware       | Hunks with actual changes, file paths, stat summary         |
| Prose / text     | Semantic         | High-information-density sentences, conclusions             |

## Never Compress Reference Data

These tool outputs must stay exact because editing tools depend on their precision:

- **Read output** -- needed for Edit tool's `old_string` matching.
- **Glob output** -- already compact file path lists.
- **Grep output** -- exact matches used for navigation.
- **Write/Edit output** -- records of what changed.

The primary compression target is **Bash output**: build logs, test results, and verbose command output.

## Stale Read Detection

Most Read output becomes obsolete during a session:

- **Stale (~67%)**: File was Read then later Edited -- the cached content is wrong.
- **Superseded (~12%)**: File was Read twice -- only the latest read matters.
- **Fresh (~20%)**: File content has not changed since reading.

Rule: When referencing file content, verify the file was not modified after the Read. Never re-read a file you just edited -- the Edit/Write tool confirms success, and the harness tracks file state.

## Preserve Structural Skeletons

For every content type, identify the skeleton and never drop it:

- **JSON**: All keys (the schema), error items, statistical outliers.
- **Code**: Import statements, function/class signatures, type annotations.
- **Logs**: Error lines, failure summaries, first and last error occurrence.
- **Arrays**: First 30% and last 15% of items (positional anchors).

Compress the flesh: values inside objects, function bodies, middle-of-array items, verbose intermediate output.

## Protect Recent Context

- **Last 4 messages**: Never compress or summarize.
- **Content under 250 tokens**: Not worth the overhead of compressing.
- **Code under active review**: Keep intact when the user asked to review it.
- **If compression increases token count**: Revert to the original.

## Learn From Failures

After a failure-then-success sequence, encode the correction:

```
Failed:  Read src/utils/helper.js     -- file not found
Success: Read lib/utils/helpers.ts    -- correct path

Learning: "helpers module is at lib/utils/helpers.ts, not src/utils/"
```

Rules for learned corrections:
- Only encode patterns with 2+ occurrences or explicit user direction.
- Every rule must be specific: "use X instead of Y", not "be careful."
- Separate stable facts (project structure) from evolving preferences.

## Output Verbosity Management

Match output length to observed user behavior:

- User interrupts frequently: output was too long. Cut ceremony.
- User responds faster than reading time: they skimmed. Be briefer.
- User says "just do it" or "skip": engage maximum brevity.

Reduction priorities (cut first):

1. **Echoing** -- repeating context the user just provided.
2. **Ceremony** -- preambles, "let me think about this," summaries of intent.
3. **Obvious explanations** -- things any developer working in this stack would know.
4. **Hedging** -- "I think," "perhaps," "it might be the case that."

## Compression Targets by Scenario

| Scenario                  | Keep % | Rationale                          |
|---------------------------|--------|------------------------------------|
| Normal coding session     | 30%    | Balance detail and window space    |
| Long session (50+ turns)  | 15%    | Aggressive to stay within budget   |
| Document/code review      | 50%    | Need detail for accurate analysis  |
| Build log analysis        | 10%    | Only errors and summaries matter   |
| Search/grep results       | 70%    | Matches are already pre-filtered   |

## Adaptive Array Sizing

When reducing large lists or arrays:

1. Track unique information as items are added.
2. Stop adding items when new information plateaus (diminishing returns).
3. If items are mostly duplicates, keep only 30%.
4. If every item is unique, keep nearly all.
5. Per-tool bias: keep more search results, less scraped page content.
