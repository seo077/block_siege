---
il_version: 1
feature: 001-core-combat-economy
phase: SPEC
size: feature
gates_passed: [G0]
spec_sha256: "9cb1ff03"
next_action: "Initialize Git and make Godot 4 available, then start the approved E1 implementation loop"
blocked_on: null
open_assumptions: []
last_verified_commit: null
head_commit: null
updated_at: "2026-08-23"
---

# 001-core-combat-economy

## Resume brief
- Goal: Deliver the fixed-scenario core combat loop with correct physical adjudication and a conserved 200-block economy.
- Done: Epic split accepted; research, interview decisions, threat model, and SPEC.md drafted.
- Now: Blocked before CRITERIA.md; three fresh packet/delegation attempts were rejected by the interlocking hook.
- Watch: Godot is not installed in the current shell but headless runtime verification is required before E1 can complete.
- Watch: This directory is not currently a Git worktree, so task-per-commit execution is unavailable until Git is initialized.

## History
- 2026-08-23: User selected E1 from the proposed epic decomposition.
- 2026-08-23: User answered "전부 권장안" to all four interview decisions.
- 2026-08-23: Drafted 10 requirements and threat mitigations; G0 remains unapproved.
- 2026-08-23: Three isolated criteria agents drafted criteria but the hook rejected every CRITERIA.md write; no criteria or review artifact was created.
- 2026-08-23: Human granted a temporary override to update the local interlocking plugin for Codex compatibility; G0 remains unapproved.
- 2026-08-23: Override used to add a project-local signed judgement-grant fallback and its regression test in the interlocking plugin; full tests and both host validators passed.
- 2026-08-23: Reinstalled interlocking as 0.1.0+codex.20260822161029 from the local marketplace; a new Codex thread is required to load it.
- 2026-08-23: Corrected the Codex signed judgement-grant consumption path; isolated il-criteria wrote criteria for all 10 requirements.
- 2026-08-23: Independent il-spec-critic returned NOT YET; REQ-004 lacks a measurable stability threshold and persistence condition.
- 2026-08-23: Amended REQ-004 with 0.12 BL/s linear and 0.2 rad/s angular thresholds sustained for 0.6 seconds after a 0.8-second minimum; prior criteria and review are invalidated.
- 2026-08-23: Isolated il-criteria rewrote all 10 criteria for the amended spec, including explicit REQ-004 boundary and persistence fixtures.
- 2026-08-23: Independent il-spec-critic returned NOT YET; turn-to-round progression and executable round-20 boundary coverage are unspecified.
- 2026-08-23: Amended REQ-008 to define ordered one-turn-per-player rounds, wrap-only increments, and immediate adjudication after the last turn of round 20.
- 2026-08-23: Isolated il-criteria rewrote all 10 criteria, adding an executable three-player turn order and round-20 boundary fixture for REQ-008.
- 2026-08-23: Independent il-spec-critic returned NOT YET; timeout retry state semantics and successful exactly-once post-retry resolution are unspecified.
- 2026-08-23: Amended REQ-009 to define timeout snapshot freezing, preserved match/shot state, timer-only reset, same-shot retry, and exactly-once successful resolution.
- 2026-08-23: Isolated il-criteria rewrote and cleaned REQ-009 criteria to cover frozen snapshots, timer-only reset, repeated timeout, and exactly-once eventual resolution.
- 2026-08-23: Independent il-spec-critic reviewed spec 9cb1ff03 and criteria efc636cb and returned READY; G0 awaits human approval.
- 2026-08-23: Human approved G0 for spec 9cb1ff03 and criteria efc636cb; code edits are unlocked.
