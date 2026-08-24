# VERIFY — 001-core-combat-economy @ HEAD
## Independence evidence
verifier: il-verifier / subagent / fresh context, implementation conversation not read
rights: read + execute; no write except this file
input: SPEC.md + CRITERIA.md + git diff af88318..HEAD
ran: repository-local Godot requirements REQ-001 through REQ-010-UI, REQ-010 --repeat 2, local browser REQ-012/013, and deployed browser REQ-012/013/014 -> all local/core runs exited 0; deployed run exited 1 because the Godot canvas/test bridge did not become ready

## Verdict
REQ-001 | PASS | repository-local Godot command printed `PASS REQ-001`; regression assertion independently enumerates two 100-block players, 200 unique IDs, fixed composition, and deterministic IDs/bindings.
REQ-002 | PASS | repository-local Godot command printed `PASS REQ-002`; scripts/core/match_state.gd:14 stores an Array[PlayerState], create_fixed_scenario preserves arbitrary ID-list order, and scripts/core/player_state.gd:1-38 contains no scene-node reference or fixed pair.
REQ-003 | PASS | repository-local Godot command printed `PASS REQ-003`; guarded-firing cases exercise eligible fire plus inactive, unloaded, and repeated rejection and verify projectile/ammunition identity and flags.
REQ-004 | PASS | repository-local Godot command printed `PASS REQ-004`; fixed-tick cases exercise minimum time, continuous quiet interval/reset, all tracked bodies, and exact 8.0-second non-mutating timeout/retry.
REQ-005 | PASS | repository-local Godot command printed `PASS REQ-005`; independent transforms cover just-below/equal displacement and rotation thresholds, all-structure collapse, and irrelevant ammunition displacement.
REQ-006 | PASS | repository-local Godot command printed `PASS REQ-006`; miss, single-kill, simultaneous-kill, unaffected ownership, exact transfers, and idempotent second application are asserted.
REQ-007 | PASS | repository-local Godot command printed `PASS REQ-007`; transition snapshots independently account for exactly 200 unique known IDs and duplicated-reference rejection preserves the snapshot.
REQ-008 | PASS | repository-local Godot command printed `PASS REQ-008`; two/three-player order, round increment, all round-20 scoring outcomes, and partial/all fortress pose fixtures are asserted.
REQ-009 | PASS | repository-local Godot command printed `PASS REQ-009`; resolving/timeout guards, frozen timeout state, same-shot retry, repeated timeout preservation, and exactly-once settlement are asserted.
REQ-010 | PASS | exact repository-local command with `--requirement REQ-010 --repeat 2` exited 0 after two full repetitions and printed `PASS REQ-010`.
REQ-011 | PASS | `--requirement REQ-010-UI` exited 0 and reported initial/resolving/timeout state labels with scene=200 ledger=200, enabled Retry, preserved shot 10, and refreshed resolving HUD.
REQ-012 | PASS | standard local Node browser command exited 0 after 11 real-browser cases; source/export/runtime UTF-8, exact oracle HUD strings, bridge fields, JSON, and PNG evidence are checked by the harness.
REQ-013 | PASS | standard local Node browser command exited 0 after real canvas pointer cases for 23/24 px thresholds, directions/elevation, 40/120/240 power, and both players, with telemetry assertions.
REQ-014 | FAIL | Criterion: the standard deployed command must exit 0 only when the live URL loads a game canvas and exact Korean HUD, a real drag fires and enters resolving, manifest hashes match, workflow succeeded, and JSON/PNG evidence is recorded. The prescribed deployed command exited 1 with `Godot canvas/test bridge did not become ready`, ran 0 browser cases, and therefore did not demonstrate the live canvas, HUD, drag, resolving transition, or deployment checks.
VERDICT: FAIL (13 pass, 1 fail, 0 inconclusive)
