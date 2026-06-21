# Project Memory System

> Mandatory for every project. Prevents knowledge loss between sessions.

## Initialization

At the start of any project interaction:

1. Check if `.claude/` exists in the project root.
2. If absent, create the full directory structure below.
3. If present, read the existing files before writing any code.

## Directory Structure

```
.claude/
  CLAUDE.md                   # Project overview (read first, always)
  progress/
    changelog.md              # Dated log of what was done
    current-task.md           # Work in progress right now
    backlog.md                # Pending tasks and ideas
  architecture/
    overview.md               # System architecture description
    decisions.md              # Architecture Decision Records (ADRs)
    patterns.md               # Patterns and conventions used
  commands/
    build.md                  # How to compile / build
    run.md                    # How to start / run
    test.md                   # How to run tests
  context/
    dependencies.md           # Key dependencies and versions
    troubleshooting.md        # Known issues and their solutions
  planners/
    _index.md                 # Registry of all plans
    [YYYY-MM-DD_slug]/        # One directory per plan
      plan.md                 # Requirements, architecture, phases
      development.md          # Implementation tracking, handoff notes
      review.md               # Post-completion review
```

All content is written in English for optimal processing.

## Context Recovery Protocol

When a session restarts or context is lost, follow this sequence before touching any code:

```
1. Read .claude/CLAUDE.md              -- project overview, tech stack
2. Read .claude/progress/current-task.md -- what was being worked on
3. Read .claude/planners/_index.md     -- check for active plans
4. If active plan exists:
   Read planners/[active]/development.md -- handoff notes from last session
5. Read .claude/progress/changelog.md  -- recent changes
6. Read .claude/architecture/decisions.md -- why things are built this way
7. Then proceed with code analysis
```

Never ask "what were we working on?" if `.claude/` exists. The answer is in `progress/current-task.md`.

## Auto-Save Triggers

Update project memory files whenever these events occur:

| Event                  | File to update                     |
|------------------------|------------------------------------|
| Task completed         | `progress/changelog.md`            |
| New task started       | `progress/current-task.md`         |
| Architectural decision | `architecture/decisions.md`        |
| Bug fixed              | `context/troubleshooting.md`       |
| Build/run command found| `commands/*.md`                    |
| Dependency added       | `context/dependencies.md`          |
| Pattern established    | `architecture/patterns.md`         |
| Complex task detected  | `planners/_index.md` + `plan.md`   |
| Implementation step    | `planners/[plan]/development.md`   |
| Plan completed         | `planners/[plan]/review.md`        |
| Session ending         | `development.md` handoff notes     |

## Plan Lifecycle

Create a plan directory when:

- The task touches 3+ files.
- Parallel agents are activated.
- The user explicitly requests a plan.
- An architectural change is being made.

Do not create a plan for simple edits or single-file bug fixes -- use `current-task.md` instead.

Plan naming: `YYYY-MM-DD_slug-name` in kebab-case, max 40 characters.

Phase transitions: `PLANNED` --> `IN_PROGRESS` --> `COMPLETED` or `ABANDONED`.

## File Size Limits

To keep files useful and prevent bloat:

| File               | Max lines | Max characters |
|--------------------|-----------|----------------|
| CLAUDE.md          | 300       | 20,000         |
| changelog.md       | 200       | 12,000         |
| plan.md            | 500       | 30,000         |
| development.md     | 400       | 25,000         |
| Other .md files    | 400       | 25,000         |

When a file reaches its limit, partition it:

1. Move the oldest 70% of content into a numbered archive file (e.g., `changelog-001.md`).
2. Keep the newest 30% in the main file.
3. Create or update `_index.md` with date ranges for each partition.

Never delete content -- only archive it.

## Reading Priority

When searching for project information, check in this order:

```
1. .claude/CLAUDE.md             -- overview, tech stack, quick commands
2. .claude/context/              -- dependencies, troubleshooting
3. .claude/architecture/         -- decisions, patterns, structure
4. .claude/planners/             -- active plans, development progress
5. .claude/commands/             -- build, run, test instructions
6. .claude/progress/             -- changelog, current task, backlog
7. Source code files             -- only after checking .claude/
```
