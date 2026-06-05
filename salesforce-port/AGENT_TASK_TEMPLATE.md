# Delegated Agent Task Template

Use this to dispatch one row of `MIGRATION_TRACKER.md` to an independent agent. Each task is self-contained: an agent needs only this prompt, the repo, and the referenced files. Designed so cheaper / automated agents can complete a row without further judgment calls.

## Per-task prompt (copy, fill `{{...}}`, dispatch)

```
You are completing one feature of the Expensify → Salesforce port.

ROW: {{ID}} — {{FEATURE}}
TRACKER: salesforce-port/MIGRATION_TRACKER.md (read your row + "Project conventions")

GOAL
Recreate the behavior of the referenced React Native source as native Salesforce
metadata under salesforce-port/force-app/main/default/ ONLY.

REFERENCE (read for behavior; treat as spec, do NOT modify):
{{REFERENCE_FILES}}

DELIVERABLES:
{{DELIVERABLES}}

CONVENTIONS (must match existing package):
- API version 60.0 in every *-meta.xml and LWC bundle.
- Apex: `public with sharing`; a Service class for logic + an Invocable* wrapper
  with inner Request/Results classes, mirroring InvocableCreateExpense.cls.
- Every new Apex class has a matching *Test.cls with >=75% coverage and meaningful asserts.
- LWC: isExposed true, correct <targets>, mirror existing bundles (expenseForm).
- Custom fields: one *.field-meta.xml per field under objects/<Object>/fields/.
- No code comments. Follow Salesforce security best practices (CRUD/FLS checks,
  `with sharing`, bind variables in SOQL).

HARD GUARDRAILS:
- Do NOT create, edit, or delete anything outside salesforce-port/.
- Do NOT touch src/, android/, ios/, web/, or any RN config. The RN app is the
  reference spec and is only removed at the final deletion gate.
- If a deliverable depends on an unfinished row, set your row to Blocked and stop.

DEFINITION OF DONE (all required):
1. `sf project deploy validate` against a scratch org succeeds for the package.
2. New Apex tests pass with >=75% coverage on each new class.
3. Your row in MIGRATION_TRACKER.md is set to Done with the commit hash, in the
   SAME commit as the code.
4. If your work fully covers an `src/` area, update the audit table row.

Work only on row {{ID}}. Commit on a branch named sf-migrate-{{ID}}.
```

## Orchestration notes (for the parent / dispatcher agent)

- **Granularity:** one subagent per tracker row. Keep them isolated (separate branches/worktrees) so they don't collide on shared files like permission sets.
- **Ordering:** dispatch a whole wave in parallel, but hold rows that declare a dependency (e.g. M11 export may depend on H2 receipts) until the dependency is `Done`.
- **Shared-file contention:** permission sets, `expenseApp` LWC, and triggers are touched by many rows. Have the parent serialize edits to those, or assign a final "integration" subagent per wave to wire new components into navigation/permission sets.
- **Cheap-agent safety:** the guardrails above (salesforce-port-only, no RN edits, no deletion) are what make a row safe to hand to a low-cost or automated agent. Deletion is never part of a feature row — it is a separate, manual final gate in the tracker.
- **Resumability:** because state lives in the tracker, a crashed or restarted run just re-reads the tracker and picks up the next `Todo`.

## Per-wave audit task (after a wave completes)

```
Audit the `src/` areas affected by the wave just completed. For each file, classify as
Ported (a Done tracker row covers it), Not Needed (matches FEATURE_AUDIT.md "Not Needed"),
or Outstanding (needs a new tracker row — add it under the right wave as Todo).
Update the "File-by-file audit" table in MIGRATION_TRACKER.md. Do not delete any files.
```
