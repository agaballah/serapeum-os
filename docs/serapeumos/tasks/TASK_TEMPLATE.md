# SerapeumOS — Task Template

This is the canonical format for all implementation tasks. Every task must
follow this structure so that execution agents receive clear, bounded
specifications rather than open-ended architecture prompts.

---

## TASK TEMPLATE

```
TASK-ID:
<TASK-NNN>

TITLE:
<Brief descriptive title>

OBJECTIVE:
<Why this task exists and the exact outcome required. One paragraph.>

AUTHORITY:
<Which MA document(s) and decision ID(s) authorize this task.>

PRECONDITIONS:
<Required repository state and dependencies before this task begins.>
- Branch: <branch name>
- Base SHA: <expected HEAD>
- Working tree: <clean / expected modifications>
- Tools: <required tools and versions>

SCOPE:
<What may change during this task.>
- Allowed files: <list of files that may be modified>
- Allowed commands: <types of commands permitted>
- Allowed outcomes: <what "done" looks like>

FORBIDDEN:
<Explicit non-goals and architecture boundaries.>
- Do not modify: <files/domains outside scope>
- Do not: <actions that would violate architecture>
- Do not claim: <unsupported qualifications>

REQUIRED BEHAVIOUR:
<Observable implementation requirements.>
- <requirement 1>
- <requirement 2>
- ...

ACCEPTANCE CRITERIA:
<Binary criteria for completion. Each must be verifiable.>
- [ ] <criterion 1 — verifiable by evidence>
- [ ] <criterion 2 — verifiable by evidence>
- [ ] <criterion 3 — verifiable by evidence>

VALIDATION:
<Tests/checks that must run.>
- <test/command 1>
- <test/command 2>
- ...

EVIDENCE:
<Exact outputs/diffs/state required in the report.>
- git diff showing changes
- command outputs proving behavior
- file reads confirming content
- test results

STOP / ESCALATE:
<Conditions where the agent must stop rather than invent a solution.>
- If precondition fails: STOP and report
- If architecture conflict found: STOP and escalate
- If evidence cannot be collected: STOP and report
- If unexpected repository state: STOP and report

GIT HANDLING:
<Branch/commit/push authority for this task.>
- Work branch: <branch name>
- Commit message: <format/template>
- Push authority: <yes/no/source>
- Merge authority: <no — PM only>

FINAL REPORT:
<Required report structure.>
- Files changed with purpose
- Tests run and results
- Evidence produced
- Residual risks
- Verdict: PASS / FAIL / BLOCKED
```

---

## Task numbering

Task IDs follow the pattern `TASK-NNN` where NNN is a zero-padded sequential
number. Numbers are assigned by the Project Manager and must not be reused.

Task IDs reference architecture documents, not implementation details. A task
should cite its MA authority, not restate the full architecture.

## Task lifecycle

1. **Proposed** — PM drafts task spec.
2. **Authorized** — PM approves and assigns to execution agent.
3. **In progress** — agent executes task.
4. **Evidence collected** — agent returns report with evidence.
5. **Accepted** — PM reviews evidence and accepts completion.
6. **Closed** — task is recorded as complete.

Only the PM moves a task from In progress to Accepted.

## Anti-patterns

- Tasks that restate full architecture instead of referencing it.
- Tasks with ambiguous acceptance criteria.
- Tasks that allow scope expansion ("and related improvements").
- Tasks that don't specify forbidden actions.
- Tasks that don't define stop/escalate conditions.
- Tasks that claim qualification without empirical evidence.
- Tasks that modify files outside their authorized scope.
