---
il_version: 1
feature: 001-core-combat-economy
phase: COMPLETE
size: feature
gates_passed: [G0]
spec_sha256: "a5372bcc"
next_action: "E1 complete; await the next requested epic or feature"
blocked_on: ""
open_assumptions: []
last_verified_commit: "a6dea47"
head_commit: "a6dea47"
updated_at: "2026-08-25"
---

# 001-core-combat-economy

## Resume brief
- Goal: Deliver the fixed-scenario core combat loop with correct physical adjudication and a conserved 200-block economy.
- Done: T-001 through T-013 implemented and the prior 11 internal/headless requirements passed.
- Now: E1 is reopened because the deployed browser path exposed broken Korean text and unusable drag firing that prior criteria did not cover.
- Watch: Godot emits sandbox-only user log and root certificate warnings, but headless requirement tests run and pass.
- Watch: The original ACL-broken Git metadata is preserved at `.git-acl-backup-20260824` until the replacement repository is fully exercised.

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
- 2026-08-24: Replaced ACL-broken Git metadata with a fresh repository linked to the preserved commits, confirmed sandbox execution, made local Godot 4.7.2 available, and verified T-001 for REQ-001/REQ-002 at 149b54d.
- 2026-08-24: Implemented and independently reverified T-002 scene binding at 106eae4; added shared Godot version-control metadata at 24edc93; next is T-003.
- 2026-08-24: Implemented T-003 guarded one-shot firing at 30d23ab; fixture-driven REQ-001/002/003 headless verification passed; next is T-004.
- 2026-08-24: Implemented T-004 fixed-tick stability and timeout adjudication at 7b79111; REQ-004 boundaries and retry timers passed; next is T-005.
- 2026-08-24: Implemented T-005 per-block baseline and collapse classification at 448f0f6; REQ-005 boundaries and destruction aggregation passed; next is T-006.
- 2026-08-24: Implemented T-006 atomic idempotent resolution ledger at a83f6aa; REQ-006/007 and rollback/duplicate invariants passed; next is T-007.
- 2026-08-24: Implemented T-007 ordered turns, fortress victory, and round-20 scoring at 8155410; REQ-008 passed; next is T-008.
- 2026-08-24: Implemented T-008 frozen timeout snapshots and exactly-once repeated retry at af2fee0; REQ-009 passed; next is T-009.
- 2026-08-24: Integrated core combat transitions into the playable scene at 7e961a8; smoke and REQ-001 through REQ-009 passed; next is T-010.
- 2026-08-24: Added HUD adjudication/conservation diagnostics and timeout Retry at 3282af9; REQ-010 UI fixture passed; next is T-011.
- 2026-08-24: Completed T-011 repeatable regression suite at 2d6b45c; REQ-001 through REQ-009, aggregate REQ-010 twice, and scene smoke passed; next is Web export and independent verification.
- 2026-08-24: Exported and locally validated the Web bundle, added GitHub Pages deployment at a68034b, and pushed master.
- 2026-08-24: Independent verification returned 8 PASS, REQ-009 FAIL for premature resolving-state callbacks, and REQ-010 INCONCLUSIVE for unavailable execution/manual observation; added T-012.
- 2026-08-24: Completed T-012 at 1822ea7; REQ-009 and the complete acceptance matrix twice passed, with premature callbacks now inert until fixed-tick settlement authorization.
- 2026-08-24: Fresh independent verification returned all requirements inconclusive because policy.verify.commands is empty; REQ-010 additionally requires human observation in an actual Godot window.
- 2026-08-24: Human approved the project-local Godot headless requirement runner for verify.commands; independent verification is ready to rerun at c31988b.
- 2026-08-24: Independent verification returned 0 PASS, 0 FAIL, and 10 INCONCLUSIVE because `godot4` was not on PATH; the repository-local executable is documented under `.tools`, so changing the verification method now requires visible amendment and re-approval.
- 2026-08-24: Human authorized amending REQ-010 to use the repository-local Godot 4 executable; prior G0 approval and acceptance criteria are invalidated pending regeneration and review.
- 2026-08-24: Design brief exposed the REQ-010 executable clause as a duplicate parsed requirement; folded it into the existing REQ-010 and invalidated the first regenerated criteria.
- 2026-08-24: Regenerated 10 acceptance criteria, then independent spec review returned NOT YET because REQ-010 lacks a reproducible method and PASS/FAIL conditions for the play-screen diagnostic UI.
- 2026-08-24: Human accepted the recommended REQ-010 amendment requiring the local regression entrypoint to instantiate the play scene and assert diagnostic state, independent totals, timeout error, and Retry behavior.
- 2026-08-24: Regenerated criteria and reran independent review; verdict remained NOT YET because REQ-010's criterion can pass without verifying initial/resolving/timeout UI states and Retry same-shot resumption plus UI refresh.
- 2026-08-24: Human approved splitting the complete UI regression contract into REQ-011 so its three states, independent totals, Retry action, same-shot resumption, and UI refresh receive a separate verdict.
- 2026-08-24: Regenerated 11 runnable criteria, but independent review returned NOT YET because every generated Method misspelled the Windows executable as a drive-root path instead of repository-relative `.\\.tools`.
- 2026-08-24: Human approved making the exact repository-relative PowerShell executable spelling normative and explicitly excluding the drive-root variant.
- 2026-08-24: Regenerated 11 criteria with valid repository-relative commands; independent critic reviewed spec 59725d80 and criteria 99db21c2 and returned READY; G0 re-approval awaits the human.
- 2026-08-24: Human re-approved G0 for spec 59725d80 and criteria 99db21c2; code edits are unlocked for the REQ-011 delta.
- 2026-08-24: Completed T-013 at 98f8c8e; actual play-scene initial/resolving/timeout diagnostics, independent scene/ledger totals, and same-shot Retry refresh passed, as did REQ-010 repeated twice.
- 2026-08-24: Human directed uninterrupted E1 completion, approving replacement of the stale verifier command with the exact repository-local PowerShell Godot runner.
- 2026-08-24: Fresh independent verification of 2d6b45c..af88318 returned PASS for all 11 requirements with 0 failures and 0 inconclusive results; E1 is complete.
- 2026-08-24: User rejected the E1 completion after observing mojibake and ineffective mouse drag on the deployed site; reopened E1 with REQ-012 UTF-8 UI, REQ-013 browser drag semantics, and REQ-014 deployed-browser smoke coverage.
- 2026-08-24: Independent review returned NOT YET for REQ-012 through REQ-014 because the spec lacks a deterministic repository-owned browser harness, string inventory/extraction method, launch instrumentation, deployment authority, and hash evidence format.
- 2026-08-24: Human approved a repository-owned Node 24 CDP harness with Godot read-only telemetry, real canvas pointer events, screenshot/JSON evidence, and local/deployed manifest hash comparison.
- 2026-08-24: Independent review returned NOT YET because REQ-012 through REQ-014 criteria had no runnable command; fixed the contract to exact Node commands, bridge schema, manifest path, and evidence outputs.
- 2026-08-24: Review exposed a contradiction between REQ-014 and the old Web-deployment exclusion; recorded authorization to commit/push build/web through the existing Pages workflow and narrowed out-of-scope to performance and multi-browser certification.
- 2026-08-24: Independent review found the Korean-string oracle could share implementation errors; bound REQ-012 to an exact normative Korean string/format inventory in SPEC for verifier-controlled comparison.
- 2026-08-24: Independent review found REQ-001 criteria relied on unstated 6/3/2 structure allocation; made the existing fixed-scenario allocation explicit in REQ-001.
- 2026-08-24: Independent critic reviewed spec a5372bcc and criteria 3a7ccb62 and returned READY for the reopened browser-quality E1 scope; G0 awaits the human.
- 2026-08-24: Human approved G0 for spec a5372bcc and criteria 3a7ccb62; code edits are unlocked for REQ-012 through REQ-014.
- 2026-08-24: Completed T-014 at 8767c21; corrected Korean runtime strings and measurable drag launch semantics passed REQ-012/013 plus existing firing/UI regressions.
- 2026-08-25: Completed T-015 at e16602f; actual Chrome canvas tests passed 11 cases, bundled Noto Sans KR rendered correctly in inspected PNG, and missing-glyph telemetry was empty.
- 2026-08-25: Completed T-016 at cb87a97; pushed the manifest-bearing Web export, Pages workflow 32743643892 succeeded, all 10 deployed hashes matched, and live Chrome evidence passed REQ-012 through REQ-014 with Korean rendering visually confirmed.
- 2026-08-25: Independent verification returned 13 PASS and REQ-014 FAIL because the deployed bridge missed the harness's 6.4-second startup window; appended corrective T-017.
- 2026-08-25: Completed T-017 at 622afa5; bounded 30-second readiness polling with diagnostic timeout preserved nonzero failure and the live 11-case REQ-014 command passed.
- 2026-08-25: Fresh independent verification of af88318..a6dea47 returned PASS for all 14 requirements with 0 failures and 0 inconclusive results; E1 is complete with live browser evidence.
