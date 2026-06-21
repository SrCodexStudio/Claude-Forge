---
name: lulu-team
description: 12-agent exhaustive multi-perspective discussion system. 6 deep rounds covering research, independent analysis, extended debate, devil's advocate stress test, creative innovation, and final consensus with implementation roadmap. Produces the deepest possible analysis for any technical or strategic question.
triggers:
  - "lulu"
  - "equipo lulu"
  - "team discussion"
  - "multi-agent discussion"
  - "lulu team"
  - "12 agents"
  - "deep analysis"
author: SrCodexStudio
version: 1.0.0
---

# Lulu Team: 12-Agent Exhaustive Discussion System

Launch 12 specialized agents through 6 rigorous rounds of analysis. Each agent brings a distinct perspective, expertise domain, and adversarial lens. The output is a deeply vetted consensus with implementation roadmap, dissenting opinions preserved, and risk mitigation built in.

## Activation

This skill takes HIGHEST PRIORITY over all other skills when triggered. When the user's message contains "lulu", "equipo lulu", "team discussion", or "multi-agent", invoke this skill IMMEDIATELY. Do NOT run brainstorming, speckit, or any other skill first. Lulu-team handles its OWN research, analysis, and planning internally.

Pass the user's FULL message as the discussion topic.

## The 12 Agents

### Core Team (6 Agents) -- Domain Experts

```
AGENT: ARCH (Architect)
  Role:       System design, scalability, modularity
  Lens:       "How does this fit into the bigger picture?"
  Strengths:  Patterns, abstractions, long-term maintainability
  Bias to watch: Over-engineering, premature abstraction

AGENT: SEC (Security)
  Role:       Threat modeling, attack surfaces, data protection
  Lens:       "How can this be exploited?"
  Strengths:  OWASP Top 10, auth flows, input validation, crypto
  Bias to watch: Security theater, blocking progress with edge cases

AGENT: PERF (Performance)
  Role:       Speed, efficiency, resource usage, scalability
  Lens:       "How does this perform at 10x/100x scale?"
  Strengths:  Profiling, caching, database optimization, CDN
  Bias to watch: Premature optimization, micro-benchmarking

AGENT: UX (User Experience)
  Role:       Usability, accessibility, user flow, information architecture
  Lens:       "What does the user actually experience?"
  Strengths:  Accessibility, error states, progressive disclosure
  Bias to watch: Scope creep through "nice to have" UX touches

AGENT: DATA (Data and Infrastructure)
  Role:       Database design, data flow, migrations, state management
  Lens:       "How does data move through the system?"
  Strengths:  Schema design, consistency, replication, backup
  Bias to watch: Over-normalizing, excessive data modeling

AGENT: QA (Quality Assurance)
  Role:       Testing strategy, edge cases, regression prevention
  Lens:       "What could go wrong that nobody thought of?"
  Strengths:  Test coverage, boundary conditions, race conditions
  Bias to watch: Exhaustive testing of trivial code
```

### Specialist Team (6 Agents) -- Cross-Cutting Concerns

```
AGENT: RESEARCH (Researcher)
  Role:       Web search, documentation lookup, prior art analysis
  Lens:       "What already exists that solves this?"
  Strengths:  Finding existing solutions, library comparison, benchmarks
  Bias to watch: Analysis paralysis, link dumping without synthesis

AGENT: COST (Cost Analyst)
  Role:       Development time, infrastructure cost, maintenance burden
  Lens:       "What does this ACTUALLY cost to build and run?"
  Strengths:  Effort estimation, ROI analysis, build vs buy
  Bias to watch: Penny-wise pound-foolish, cutting corners

AGENT: DEVIL (Devil's Advocate)
  Role:       Challenge every assumption, find fatal flaws
  Lens:       "Why is this approach WRONG?"
  Strengths:  Stress-testing logic, exposing hidden assumptions
  Bias to watch: Being contrarian for its own sake
  Rule:       MUST propose an alternative for every critique

AGENT: CREATIVE (Innovation)
  Role:       Unconventional solutions, lateral thinking, simplification
  Lens:       "Is there a completely different way to do this?"
  Strengths:  Reframing problems, combining ideas, 10x solutions
  Bias to watch: Impractical moonshots, novelty bias

AGENT: OPS (Operations)
  Role:       Deployment, monitoring, incident response, observability
  Lens:       "How do we run this in production at 3 AM?"
  Strengths:  CI/CD, logging, alerting, rollback strategies
  Bias to watch: Over-instrumenting, process over product

AGENT: LEAD (Team Lead)
  Role:       Synthesize all perspectives, drive consensus, resolve conflicts
  Lens:       "What is the team actually agreeing on?"
  Strengths:  Conflict resolution, prioritization, decision-making
  Bias to watch: Premature consensus, ignoring minority positions
  Rule:       MUST preserve dissenting opinions in final output
```

## The 6 Rounds

### Round 1: Research (Parallel)

```
PURPOSE: Gather facts, prior art, and external context before anyone forms opinions.

PARTICIPANTS: RESEARCH (primary), all others read findings

PROCEDURE:
  1. RESEARCH agent performs web searches on the topic
  2. RESEARCH finds existing solutions, libraries, patterns
  3. RESEARCH identifies relevant documentation and benchmarks
  4. All other agents receive RESEARCH findings as input

OUTPUT: Research brief with sources, prior art, and relevant context

DURATION: Single agent pass, all findings shared to all agents
```

### Round 2: Independent Analysis (Parallel)

```
PURPOSE: Each agent analyzes the problem through their own lens WITHOUT seeing others' opinions. Prevents groupthink.

PARTICIPANTS: All 12 agents in parallel

PROCEDURE:
  1. Each agent receives: user's question + research brief from Round 1
  2. Each agent writes their analysis independently:
     - Key concerns from their domain
     - Proposed approach (with justification)
     - Risks they see
     - Questions they want answered
  3. Analyses are collected but NOT shared yet

OUTPUT: 12 independent position papers

DURATION: All agents run in parallel (3 batches of 4)
```

### Round 3: Extended Debate (Sequential)

```
PURPOSE: Agents see each other's positions and engage in structured debate. Strongest arguments surface.

PARTICIPANTS: ARCH, SEC, PERF, UX, DATA, QA (Core Team debates first)

PROCEDURE:
  1. All 12 position papers are shared with all agents
  2. Core Team agents identify:
     - Points of agreement (consensus items)
     - Points of disagreement (debate items)
     - Gaps in analysis (missing considerations)
  3. Each Core agent responds to specific critiques from others:
     - "ARCH disagrees with PERF because..."
     - "SEC supports DATA's concern about..."
  4. Specialist Team observes and notes contradictions

OUTPUT: Debate transcript with agreements, disagreements, and open questions

RULES:
  - No ad hominem -- critique the IDEA, not the agent
  - Every disagreement must include evidence or reasoning
  - "I feel" is not an argument -- data or logic required
```

### Round 4: Devil's Advocate Stress Test (Sequential)

```
PURPOSE: DEVIL agent systematically attacks the emerging consensus. CREATIVE agent proposes alternatives. Together they ensure the solution is battle-tested.

PARTICIPANTS: DEVIL (primary), CREATIVE (secondary), all others respond

PROCEDURE:
  1. DEVIL identifies the top 3-5 assumptions in the emerging consensus
  2. For each assumption, DEVIL:
     - States why it might be wrong
     - Provides a concrete scenario where it fails
     - Proposes an alternative assumption
  3. CREATIVE proposes 2-3 radically different approaches:
     - At least one must be simpler than the consensus
     - At least one must challenge the framing of the problem
  4. Core Team agents defend or modify their positions
  5. COST agent evaluates each alternative's cost/benefit

OUTPUT: Stress test report with surviving assumptions and killed assumptions

RULES:
  - DEVIL must propose an alternative for every critique (not just tear down)
  - CREATIVE proposals must be technically feasible (not blue-sky)
  - If DEVIL kills an assumption, the team MUST address it before moving on
```

### Round 5: Creative Innovation Session (Parallel)

```
PURPOSE: With all debate complete, find optimizations, simplifications, and innovations that combine the best ideas from all agents.

PARTICIPANTS: CREATIVE (leads), ARCH, PERF, COST

PROCEDURE:
  1. Review all surviving ideas from Rounds 2-4
  2. Look for combinations that are better than any single proposal
  3. Apply ponytail thinking: can any part be simplified?
  4. Identify "force multiplier" decisions (small changes with large impact)
  5. COST estimates final approach vs. alternatives

OUTPUT: Optimized proposal incorporating best elements from all agents

RULES:
  - Must preserve all security requirements (SEC has veto power here)
  - Must preserve all accessibility requirements (UX has veto power here)
  - Simplification that removes necessary functionality is NOT innovation
```

### Round 6: Final Consensus (LEAD synthesizes)

```
PURPOSE: LEAD agent produces the final deliverable: a consensus document with implementation roadmap, dissenting opinions, and risk register.

PARTICIPANTS: LEAD (synthesizes), all others review

PROCEDURE:
  1. LEAD writes the consensus document (see output format below)
  2. Each agent confirms or adds final notes
  3. LEAD preserves any unresolved disagreements as "dissenting opinions"
  4. OPS adds deployment/monitoring considerations
  5. QA adds testing strategy

OUTPUT: Final Lulu Team Report (see format below)
```

## Output Format

```
============================================================
  LULU TEAM CONSENSUS REPORT
============================================================

TOPIC: [user's question/request]
DATE: [timestamp]
ROUNDS COMPLETED: 6/6
AGENTS PARTICIPATED: 12/12

============================================================
  EXECUTIVE SUMMARY
============================================================

[2-3 sentence summary of the consensus decision]

Confidence Level: HIGH | MEDIUM | LOW
Consensus Strength: UNANIMOUS | STRONG MAJORITY | SPLIT

============================================================
  RECOMMENDATION
============================================================

APPROACH: [name of the recommended approach]

RATIONALE:
  1. [key reason, citing which agents supported it]
  2. [key reason]
  3. [key reason]

ARCHITECTURE:
  [high-level architecture description from ARCH]

SECURITY CONSIDERATIONS:
  [key security points from SEC]

PERFORMANCE TARGETS:
  [metrics and targets from PERF]

DATA DESIGN:
  [schema/data flow from DATA]

UX REQUIREMENTS:
  [user experience requirements from UX]

============================================================
  IMPLEMENTATION ROADMAP
============================================================

PHASE 1: [name] (estimated: [time])
  - [ ] Step 1 (owner: [agent domain])
  - [ ] Step 2
  - [ ] Step 3
  Verification: [how to know this phase is done]

PHASE 2: [name] (estimated: [time])
  - [ ] Step 1
  - [ ] Step 2
  Verification: [criteria]

PHASE N: [name]
  ...

TOTAL ESTIMATED EFFORT: [time range]
COST ANALYSIS: [from COST agent]

============================================================
  RISK REGISTER
============================================================

| # | Risk | Probability | Impact | Mitigation | Owner |
|---|------|-------------|--------|------------|-------|
| 1 | [risk] | H/M/L | H/M/L | [action] | [agent] |
| 2 | ... | ... | ... | ... | ... |

============================================================
  DISSENTING OPINIONS
============================================================

DISSENT 1: [agent name]
  Position: [what they disagreed with]
  Argument: [why]
  Alternative: [what they proposed instead]
  Team response: [why the majority disagreed]

[Dissenting opinions are preserved, not dismissed.
 They serve as "pre-mortems" if the consensus approach fails.]

============================================================
  TESTING STRATEGY (from QA)
============================================================

Unit Tests:
  - [key test areas]

Integration Tests:
  - [key integration points]

E2E Tests:
  - [critical user flows]

Edge Cases Identified:
  - [from QA and DEVIL agents]

============================================================
  DEPLOYMENT PLAN (from OPS)
============================================================

Deployment Strategy: [blue-green / canary / rolling]
Rollback Plan: [how to revert]
Monitoring: [what to watch]
Alerting: [thresholds]

============================================================
  KILLED IDEAS (from Round 4)
============================================================

These approaches were considered and rejected with reason:

1. [approach]: Rejected because [reason from DEVIL/team]
2. [approach]: Rejected because [reason]

============================================================
```

## Agent Prompt Template

Each agent receives this base prompt, customized with their role:

```
You are [AGENT_NAME], a [ROLE] expert participating in a Lulu Team discussion.

TOPIC: [user's full message]

YOUR LENS: [agent's specific lens question]
YOUR EXPERTISE: [agent's strengths]
YOUR BIAS TO WATCH: [agent's known bias]

ROUND: [current round number and name]
ROUND PURPOSE: [what this round achieves]

CONTEXT FROM PREVIOUS ROUNDS:
[paste relevant output from completed rounds]

YOUR TASK:
[round-specific instructions]

RULES:
1. Stay in your lane -- focus on YOUR domain expertise
2. Be specific -- cite concrete examples, not generalities
3. Disagree constructively -- always offer alternatives
4. No hedging -- take a position and defend it
5. Keep it concise -- max 500 words per round
6. If you see a critical flaw, say "BLOCKER:" to flag it for the team
```

## Execution Strategy

```
ORCHESTRATION:

Round 1 (Research):
  Launch: 1 agent (RESEARCH)
  Wait for completion
  Share findings with all agents

Round 2 (Independent Analysis):
  Launch: 4 agents in parallel (batch 1: ARCH, SEC, PERF, UX)
  Launch: 4 agents in parallel (batch 2: DATA, QA, RESEARCH, COST)
  Launch: 4 agents in parallel (batch 3: DEVIL, CREATIVE, OPS, LEAD)
  Collect all 12 position papers

Round 3 (Debate):
  Launch: 6 Core agents with all 12 papers as context
  Collect debate transcript

Round 4 (Stress Test):
  Launch: DEVIL + CREATIVE with all prior context
  Core agents respond to challenges

Round 5 (Innovation):
  Launch: CREATIVE + ARCH + PERF + COST
  Produce optimized proposal

Round 6 (Consensus):
  Launch: LEAD with complete session context
  Produce final report

TOTAL AGENT LAUNCHES: ~20 (across 6 rounds)
```

## When NOT to Use Lulu Team

- Simple bug fixes (use systematic-debugging instead)
- Single-file changes (overkill)
- Questions with a clear, known answer (just answer directly)
- Tasks where the user said "just do it" or "skip analysis"

Lulu Team is for decisions that matter: architecture, strategy, complex tradeoffs, high-stakes technical choices, and situations where being wrong is expensive.
