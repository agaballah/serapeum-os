# SerapeumOS — Evidence and Completion Contract

This document defines the evidence standards that every execution agent must
meet. It applies to all bounded tasks across all MA domains.

## Evidence hierarchy

| Level | Description | Examples |
|---|---|---|
| L1 — Direct observation | What the agent saw with its own tools | git status, file reads, command output |
| L2 — Verified computation | Calculated or derived from L1 evidence | checksums, diffs, line counts |
| L3 — External confirmation | State confirmed via API or separate process | gh API responses, remote refs |
| L4 — Test pass | Automated test produced expected output | unit test green, integration test green |
| L5 — Human acceptance | Project Manager reviews and accepts evidence | PM sign-off on report |

L1 is the minimum for any factual claim. L4 is required for implementation
tasks. L5 is required for task completion.

## Evidence requirements by claim type

### "File X exists"
- L1: `cat` or file read returning content
- Must show path and non-empty content

### "File Y was modified"
- L1: `git diff` showing the change
- L2: diff stat confirming line count change
- Must show before/after for substantive changes

### "Command Z succeeded"
- L1: command output showing expected result
- Must NOT rely on exit code alone
- Must show the actual output

### "Test passed"
- L4: test framework output showing PASS
- Must include test name and assertion

### "Repository state is S"
- L3: `gh api` or `git ls-remote` confirming remote state
- L1: local `git` command confirming local state

### "Artifact has digest D"
- L2: hash computation (`sha256sum`, `certutil -hashfile`, etc.)
- Must show command and result

## Forbidden evidence practices

- Inferring success from exit code without output verification.
- Claiming a file was created without reading it back.
- Claiming a test passed without showing test output.
- Using chat history as evidence of repository state.
- Confusing model memory with repository truth.
- Claiming qualification without empirical evidence.
- Stating "should work" as evidence.

## Evidence retention

Evidence must be:

- Reproducible — another agent running the same commands should get the same
  result.
- Time-stamped — include the date/time of evidence collection where material.
- Complete — include enough context that the evidence can be independently
  verified.

## Completion report template

Every task report must include:

```
Task ID: <id>
Branch: <branch>
Base SHA: <sha>
New SHA: <sha>

Changes:
- <file>: <what changed and why>

Evidence:
- <L1/L2/L3/L4 evidence for each claim>

Acceptance criteria met:
- [ ] <criterion 1>
- [ ] <criterion 2>
- ...

Unresolved issues:
- <none or description>

Recommendation:
- <next action or escalation needed>
```

## PM acceptance

Only the Project Manager can accept task completion. An execution agent must
explicitly request acceptance and await PM response before considering a task
complete.
