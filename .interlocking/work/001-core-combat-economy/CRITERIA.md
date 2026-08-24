# Acceptance Criteria — 001-core-combat-economy

REQ-001
  Judged: A fresh fixed scenario reports exactly 2 players; each independently reports 1 fortress, 1 loaded catapult, 1 loaded tank, 87 reserve blocks, and 100 owned blocks, while an independent enumeration of every unique block ID reports exactly 200; rebuilding the scenario produces the same ID set and the play scene binds every enumerated block.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-001`

REQ-002
  Judged: For player lists `[7,3]`, `[30,10,20]`, and `[20,30,10]`, the headless fixture preserves the supplied order and IDs, independently resolves each ID to its own reserve, fortress, weapons, and turn-action state, and mutating one player's per-turn shot count leaves all others at 0; the core state source contains no scene-node-typed field and no fixed two-player pair lookup.
  Method: Run `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-002`, then inspect `scripts/core/match_state.gd` and `scripts/core/player_state.gd` for the state types exercised by that fixture.

REQ-003
  Judged: A drag by the active player against each loaded, not-yet-fired weapon creates exactly one projectile carrying that weapon's former ammo block ID and immediately leaves the weapon with no ammo and `fired_this_turn=true`; attempts by an inactive player, with an unloaded weapon, or to repeat-fire the same weapon create 0 additional projectiles and leave the request rejected.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-003`

REQ-004
  Judged: On fixed 0.1 s physics ticks, no shot resolves before 0.8 s; linear speed exactly 0.12 BL/s and angular speed exactly 0.2 rad/s qualify while 0.121 BL/s or 0.201 rad/s do not; qualifying motion must persist continuously for 0.6 s and any failing tick resets that interval; motion still failing at exactly 8.0 s enters an explicit timeout with retry available and with destruction, ownership, and match result snapshots unchanged.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-004`

REQ-005
  Judged: Against a separately captured stable transform per structure block, displacement below half the block's short edge and rotation below 30 degrees are standing, while displacement exactly half the short edge or rotation exactly 30 degrees are fallen; mixed baselines do not cross-contaminate blocks, an object is destroyed only when every structure block is fallen, and moving its loaded ammo alone never contributes to destruction.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-005`

REQ-006
  Judged: For one settled shot, fixtures independently force zero, one, and two enemy weapons to complete destruction: zero transfers only the fired block to the defender's reserve; one or two transfer the fired block plus every structure and loaded-ammo block of every destroyed weapon to the attacker's reserve; unaffected weapons retain ownership, and replaying the same resolution changes no ID or ownership a second time.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-006`

REQ-007
  Judged: Independent ID enumeration after initialization, firing, delete-pending processing, timeout, retry, settled multi-destruction, and duplicate callbacks always finds exactly 200 known unique IDs across reserves, field structures, loaded ammo, and the active projectile, with 0 missing, 0 unknown, and 0 duplicate placements; a deliberately duplicated reference is detected and a transaction presented with it is rejected without partial mutation.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-007`

REQ-008
  Judged: With ordered lists of 2 and 3 arbitrary player IDs, round 1 begins at index 0, each accepted end-turn advances exactly once in list order, only the last player's end-turn increments the round, and round 20's last end-turn produces a final result without round 21; separate fixtures settle the winner by total owned blocks first, current fortress-owned blocks second, otherwise draw, while collapse of all (but not a proper subset) of an enemy fortress's structure blocks ends immediately for the attacker without altering the supplied pose snapshot.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-008`

REQ-009
  Judged: During resolving and timeout states, attempted new fire, end-turn, and repeated resolution callbacks are rejected; at timeout the active player, round, weapon ammo/fired flags, all block IDs/owners, and every adjudicated body's transform plus linear and angular velocity match a pre-timeout snapshot. Retry restores that same shot ID and frozen body values, creates and transfers 0 blocks, and resets only elapsed and continuous-quiet time to 0.0 s; both a second exact 8.0 s timeout and a later qualifying settlement are exercised, and settlement applies ownership/results exactly once.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-009`

REQ-010
  Judged: Two consecutive runs in one process report explicit PASS results for fixed initialization, firing success/failure, zero/one/multiple destruction, fortress victory, every round-20 tiebreak outcome, timeout hold/retry, and the 200-ID invariant; the invoked executable is exactly the repository-local Godot 4 binary, and the play scene exposes readable adjudication-state and independently counted total-block diagnostics.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010 --repeat 2`

REQ-011
  Judged: A headless-created play scene is sampled in initial, resolving, and timeout states; in each, its visible adjudication-state name matches the independently observed state and its displayed total equals both an independent scene-node count and an independent match-ledger count of exactly 200. In timeout, an explicit error and enabled Retry control are present; activating Retry preserves the shot block ID, resumes resolving that shot, and immediately refreshes the visible status, with every subcase emitting an explicit pass or failure.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010-UI`
