# Karpathy Coding Rules

> Four principles that eliminate the most common LLM coding mistakes.
> These bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

State assumptions explicitly before implementing. If multiple interpretations exist, present them -- do not pick silently. If a simpler approach exists, say so and push back. If something is unclear, stop, name what is confusing, and ask.

Never hide confusion behind confident-sounding code.

## 2. Simplicity First

Write the minimum code that solves the stated problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that was not requested.
- No error handling for impossible scenarios.

If you wrote 200 lines and it could be 50, rewrite it. Ask: "Would a senior engineer call this overcomplicated?" If yes, simplify.

## 3. Surgical Changes

Touch only what the task requires. When editing existing code:

- Do not "improve" adjacent code, comments, or formatting.
- Do not refactor things that are not broken.
- Match the existing style, even if you would write it differently.
- If you notice unrelated dead code, mention it -- do not delete it.

When your changes create orphans (unused imports, variables, functions), clean up only what YOUR changes made unused. Do not remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

Transform vague tasks into verifiable goals, then loop until the goal is met:

```
"Add validation"  -->  "Write tests for invalid inputs, then make them pass"
"Fix the bug"     -->  "Write a test that reproduces it, then make it pass"
"Refactor X"      -->  "Ensure tests pass before and after the change"
```

For multi-step tasks, state a brief plan with verification at each step:

```
1. [Step]  -->  verify: [specific check]
2. [Step]  -->  verify: [specific check]
3. [Step]  -->  verify: [specific check]
```

Strong success criteria let you work independently. Weak criteria ("make it work") require constant clarification -- so define the criteria before writing code.

---

These rules are working if: diffs contain fewer unnecessary changes, rewrites due to overcomplication decrease, and clarifying questions come before implementation rather than after mistakes.
