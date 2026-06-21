# Parallel Agent Orchestration

> Automatic multi-agent execution for complex tasks involving 3+ files or modules.

## Activation Criteria

Activate parallel agents when the user requests work that spans multiple files or modules:

- "Create a plugin / project / application"
- "Build a complete system"
- "Develop a full feature with tests"
- Any task requiring 3 or more files

Do NOT activate for: single-file edits, bug fixes, questions, explanations, or tasks touching 1-2 files.

## Agent Roles

Eight agents, each with a distinct responsibility:

| Agent | Role           | Scope                                      |
|-------|----------------|---------------------------------------------|
| 1     | Architect      | Project structure, build config, entry point |
| 2     | Database       | Models, repositories, migrations, schema     |
| 3     | Services       | Business logic, DTOs, caching layer          |
| 4     | Controllers    | Commands, routes, request/response handling   |
| 5     | Events         | Listeners, observers, lifecycle hooks         |
| 6     | API            | Public interfaces, external integrations      |
| 7     | Tests          | Unit tests, integration tests, fixtures       |
| 8     | Security       | Validators, permissions, sanitization         |

## Phase 0: Pre-Launch (Orchestrator)

Before launching any agent, the orchestrator must:

1. **Detect project type** from markers (package.json, composer.json, build.gradle.kts, go.mod).
2. **Assess complexity**: 3-5 files = 4 agents, 6+ files = 8 agents.
3. **Write code contracts** -- exact signatures for every cross-module boundary.
4. **Define scope contracts** per agent: allowed files, forbidden files, acceptance criteria.

## Code Contracts

The root cause of integration failures is agents inventing incompatible APIs. The fix: the orchestrator writes exact code contracts before any agent launches.

Every agent receives the same contract block in its prompt. The contract includes:

- Class/function names and their exact signatures (parameters + return types).
- Constructor parameters with types.
- Callback signatures.
- Exact import paths between modules.
- Which classes the agent implements and which it consumes.

No ambiguity. If the contract says `UserService.find_by_id(id: int) -> User | None`, every agent that calls or implements this method uses that exact signature.

## Scope Contracts

Each agent's prompt includes boundaries:

```
Agent 2 (Database):
  allowed_files:      ["src/database/**", "src/models/**"]
  forbidden_files:    ["src/commands/**", "src/api/**", "build.gradle.kts"]
  acceptance_criteria: ["project compiles", "all imports resolve"]
```

An agent that writes outside its allowed files is rejected. An agent that touches forbidden files is blocked and re-run.

## Phase 1: Three-Round Execution

Do NOT launch all agents simultaneously. Use three rounds so later agents reference actual output from earlier rounds.

### Round 1 -- Foundation (no dependencies)

Launch in parallel:
- Agent 1: Architect (structure, build config, entry point)
- Agent 2: Database (models, repositories, schema)
- Agent 8: Security (validators, permission checks)

Wait for Round 1 to complete. Read the actual files created.

### Round 2 -- Core Logic (depends on Round 1 output)

Launch in parallel:
- Agent 3: Services (imports real models from Agent 2's output)
- Agent 6: API (imports real interfaces from Agent 1's output)
- Agent 7: Tests (imports real classes from Agents 1 + 2)

Each agent's prompt includes the actual code from Round 1, not descriptions.

Wait for Round 2 to complete. Read the actual files created.

### Round 3 -- Integration (depends on Rounds 1 + 2 output)

Launch in parallel:
- Agent 4: Controllers (imports real services from Agent 3)
- Agent 5: Events (imports real services from Agent 3)

## Phase 2: Verification Gates

After all three rounds complete, run deterministic checks -- not LLM judgment.

### Gate 1: Scope Check

For each agent's output files:
- File in `allowed_files`? PASS.
- File in `forbidden_files`? BLOCK -- reject and redo.
- File not in either list? WARN -- flag for review.

### Gate 2: Contract Check

For each file's imports:
- Does the imported file exist? PASS.
- Does the imported class/function match the contract signature? PASS.
- Signature mismatch? BLOCK -- fix the caller to match the implementation.

Zero tolerance. Every mismatch is a BLOCK.

### Gate 3: Build Check

Run the project's build command. Exit code 0 = PASS. Non-zero = read the error, find root cause, fix one issue at a time, re-verify after each fix.

### Gate 4: Acceptance Check

Run each agent's `acceptance_criteria` commands. All exit 0 = PASS. Any non-zero = BLOCK, fix, and re-run.

### Verdict

All gates passed with zero BLOCKs = task complete. Any remaining BLOCKs = list findings, fix, and re-run the gates.

Never say "integration errors are expected." Contracts prevent them. Never declare success without running all four gates.

## Conflict Resolution

When two agents touch the same concern, higher-priority agent wins:

```
Priority (highest first):
1. Architect     -- build files, main config
2. Security      -- validation, permissions
3. Database      -- models, schemas
4. Services      -- business logic
5. Controllers   -- routes, commands
6. Events        -- listeners
7. API           -- external interfaces
8. Tests         -- test files
```

For import conflicts, merge both. For dependency version conflicts, use the latest stable. For naming collisions, prefix with the module name.
