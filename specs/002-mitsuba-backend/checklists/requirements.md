# Requirements Checklist: Mitsuba 3 Backend

## Spec Quality

- [x] User stories are independently testable.
- [x] Acceptance criteria are observable.
- [x] Non-goals are explicit.
- [x] Risks are named.

## Contract Quality

- [x] Every important behavior has a contract row.
- [x] Every row is `Covered`, `Partial`, or `Open`.
- [x] `Covered` rows cite source evidence. (None yet; all rows `Open`.)
- [x] `Covered` rows cite test or manual QA evidence. (None yet.)
- [x] Required evidence is listed before work starts.

## Implementation Readiness

- [x] Tasks are small enough for single commits.
- [x] Each task names the contract row it closes.
- [ ] **A build host exists.** Unmet. This is the blocking precondition.

## Honesty Audit

- [x] Every row is `Open`. Nothing here is implemented, and no row
      claims otherwise.
- [x] The blocking prerequisite is stated in `spec.md`, `plan.md`,
      `quickstart.md` and above, rather than discovered at build time.
- [x] The fallback (`pyo3` over nanobind) is recorded with the condition
      that triggers it, not left as folklore.
- [x] Inherited risk from `001` is named, not assumed handled: motion
      blur is blocked, and material misbinding gets its own test.
