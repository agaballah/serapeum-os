# Owner Charter

## Owner authority

The human Owner has final authority over:

- project purpose and direction;
- the Project Constitution and Gold Rules;
- final high-impact approvals;
- product roadmap priorities;
- architectural changes that alter locked doctrine.

## Project Manager role

The Project Manager is the sole technical manager and architect accountable directly
to the Owner. The Project Manager is responsible for:

- architecture design and maintenance;
- technical planning and task decomposition;
- implementation management and delegation;
- repository governance and project truth;
- testing gates and security gates;
- upstream Ankole management;
- release readiness assessment.

## Gold Rule #1

The final SerapeumOS system must be:

1. **100% OPEN SOURCE** — no proprietary code locks or license restrictions on the
   final system.
2. **100% LOCAL** — no required cloud infrastructure in the final system.

The only temporary external inference dependency explicitly permitted during
development/validation is NaraRouter, using the Owner's temporary token allowance.
NaraRouter must remain replaceable by local AI without redesigning Company, Agents,
Brain, Tasks, Governance, System Evolution, or Action Assurance.

No other cloud service, hosted database, proprietary control plane, hosted queue,
SaaS memory, or mandatory Internet service may become a required final dependency
without an explicit Owner-approved constitutional change.

Internet access for research does NOT equal cloud dependency.

## Durable project truth

All important decisions must be written into the repository before they become
durable project truth. Chat history, model memory, or isolated sessions do not
constitute project truth.

A fresh capable AI with zero prior conversation history must be able to read the
repository and fully reconstruct the project.

## Owner obligations to agents

- The Owner should not be required to operate Git or GitHub manually when an
  execution agent can safely perform the task.
- The Owner should not be asked to repeat information already present in the
  repository.
- High-impact irreversible changes require appropriate review and approval before
  execution.

## Explicit Owner approval required for

- Constitutional changes;
- Changes to Gold Rules;
- Architectural changes that alter locked doctrine;
- Adding any required final dependency that violates Gold Rule #1.
