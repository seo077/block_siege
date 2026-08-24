REQ-001
  Judged: A newly created match reports exactly two players; each independently totals 100 uniquely identified blocks comprising 87 reserve blocks, one 6-structure-block fortress, one loaded 3-structure-block catapult, and one loaded 2-structure-block tank, for exactly 200 unique blocks overall; rebuilding the scenario produces the same IDs and scene bindings.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-001`

REQ-002
  Judged: Creating matches with player ID lists `[7,3]`, `[30,10,20]`, and `[20,30,10]` preserves list order and gives every entry the same identifier, reserve, fortress, weapons, and per-turn-action interface; changing one entry's action state leaves every other entry unchanged. Source inspection must additionally find no scene-node reference or fixed two-player pair in the core match/player state classes.
  Method: Run `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-002`, then inspect `scripts/core/match_state.gd:1` and `scripts/core/player_state.gd:1`.

REQ-003
  Judged: For each player, one eligible loaded weapon accepts one drag and creates exactly one projectile bearing the former ammunition block ID, immediately leaves the weapon unloaded and marked fired for that turn, and rejects inactive-player, unloaded, and repeated-fire attempts without creating another projectile.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-003`

REQ-004
  Judged: Fixed-tick cases remain resolving before 0.8 s; only settle after every tracked body stays at or below 0.12 BL/s linear and 0.2 rad/s angular speed continuously for 0.6 s; any above-threshold tick resets that interval; unresolved motion reaches timeout at exactly 8.0 s with retry available and no destruction, ownership, or victory mutation.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-004`

REQ-005
  Judged: Against independently supplied baseline/current transforms, a structure block is fallen at displacement equal to half its 0.2 BL short side (0.1 BL) or rotation equal to 30 degrees, not just below either boundary; an object is destroyed only when every structure block is fallen, and arbitrary ammunition displacement does not affect that result.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-005`

REQ-006
  Judged: Independent no-kill, single-kill, and simultaneous-multi-kill pose fixtures transfer exactly the fired block to the defender on failure, or exactly the fired block plus every structure and loaded-ammunition block of every destroyed enemy weapon to the attacker on success; unaffected weapons remain owned by the defender and applying the same resolution twice makes no second change.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-006`

REQ-007
  Judged: After initialization, firing, successful resolution, failed resolution, multi-destruction, delete-pending handling, timeout, retry, duplicate callback, and deliberately duplicated-reference rejection, an independent enumeration of reserve, field structure, loaded ammunition, and active projectile IDs contains exactly 200 unique known IDs with no missing, extra, or multiply located ID; rejected transactions leave the full snapshot unchanged.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-007`

REQ-008
  Judged: Two- and three-player fixtures begin at round 1 with the first list entry active, advance exactly once through list order, and increment only after the last entry; round 20 ends immediately after the last turn without creating round 21 and selects by total owned blocks, then fortress-owned blocks, then draw. Independently supplied poses ending all, but not merely some, enemy fortress blocks end the match immediately for the attacker without changing those poses.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-008`

REQ-009
  Judged: While resolving and while timed out, new fire, turn end, and duplicate result callbacks are rejected. At each 8.0 s timeout, independently captured projectile/target transforms, linear/angular velocities, active player, round, weapon/turn flags, all IDs, and ownership remain identical and bodies are frozen. Retry restores that same shot, creates no shot or transfer, resets only elapsed and continuous-quiet time to zero, then either times out under the same preservation rule or settles once and applies exactly one result.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-009`

REQ-010
  Judged: Two consecutive runs through initialization, guarded firing, threshold/failure/success/multi-destruction, fortress victory, ordered turns/round-20 scoring, timeout/retry, UI diagnostics, and independent 200-ID accounting all pass under the repository-local Godot 4 executable; the play scene visibly reports adjudication state and independently counted total blocks.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010 --repeat 2`

REQ-011
  Judged: Instantiating the real play scene in initial, resolving, and timeout states yields a visible state label and total equal to a separate enumeration of scene bodies and match-state IDs; timeout visibly supplies an enabled error/Retry control, and activating it preserves the shot ID, resumes resolving, and updates the displayed state with an explicit pass/fail result.
  Method: `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010-UI`

REQ-012
  Judged: The source and Web export decode as UTF-8; a real browser's HUD and `globalThis.__BLOCK_SIEGE_TEST__` expose the complete SPEC-owned Korean oracle character-for-character, contain neither U+FFFD nor known UTF-8-to-legacy corruption, and expose every required bridge field. The standard run writes a passing JSON result and PNG screenshot, while an injected source, export, runtime-string, or missing-field mismatch exits nonzero.
  Method: `node tests/web/run_browser_regression.mjs --base-url http://127.0.0.1:8060 --serve build/web --requirements REQ-012,REQ-013 --evidence build/web-evidence/local`

REQ-013
  Judged: Fresh-game browser cases sending real canvas press/move/release events produce no shot at 23 px and exactly one at 24 px; left/right drags change aim with matching sign, upward drag increases elevation, 40/120/240 px impulse is strictly increasing, and equivalent drags for both players point toward the opponent from their own camera. JSON evidence contains received coordinates, shot ID/count, initial velocity, impulse, normalized direction, active player, and ready-to-resolving state; any violated boundary, direction, output, or bridge case exits nonzero.
  Method: `node tests/web/run_browser_regression.mjs --base-url http://127.0.0.1:8060 --serve build/web --requirements REQ-012,REQ-013 --evidence build/web-evidence/local`

REQ-014
  Judged: A fresh load of the deployed URL shows the game canvas and exact Korean HUD; a real canvas drag creates exactly one measured shot and changes ready to resolving. `build/web/build-manifest.json` names the approved source commit and SHA-256 for every deployed relative asset, all live hashes match, the Pages workflow succeeded, and JSON evidence records URL, commit, comparisons, HUD, pointer/shot telemetry, workflow result, and PNG path; a stale or tampered commit/asset exits nonzero.
  Method: `node tests/web/run_browser_regression.mjs --base-url https://seo077.github.io/block_siege/ --requirements REQ-012,REQ-013,REQ-014 --manifest build/web/build-manifest.json --evidence build/web-evidence/deployed`

REQ-015
  Judged: From identical fresh fixed scenarios for both players, a zero-lateral 240 px catapult drag launches toward the opponent and its projectile center reaches x>=20 BL for player 1 or x<=-20 BL for player 2 within 8.0 s. For each player, independently sampled opponent-direction maximum progress for 40, 120, and 240 px drags is strictly increasing, and no sample initially or subsequently progresses behind its own firing direction.
  Method: Run `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-015`, inspecting the emitted per-player time/position and maximum-progress samples.

REQ-016
  Judged: A standard valid fixed-scenario shot does not enter or remain in timeout: crossing x=+/-30 BL, z=+/-15 BL, or y<-2 BL freezes the projectile on that fixed tick, keeps it tracked, honors the 0.8 s minimum and continuous 0.6 s quiet interval, applies ownership/victory exactly once, and ends in ready or final. Enter cannot change turns while resolving; after a ready result the HUD explicitly includes `[Enter]: 턴 종료`.
  Method: Run `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-016`, covering each positive/negative field boundary, below-field fall, duplicate resolution, resolving Enter, and post-resolution HUD cases.

REQ-017
  Judged: On independent fresh loads of both the local Web export and deployed URL, a real player-1 canvas 240 px press/move/release shot reaches x>=20 BL within 8.0 s with timestamped position samples, never times out, and transitions resolving to ready. A real Enter keydown/keyup before resolution leaves player and round unchanged; one after resolution changes active player exactly once from 1 to 2, keeps round 1, and refreshes player-2 camera, HUD, and enabled input. Each run writes JSON containing positions, states, and input evidence plus a PNG; any missing or contrary observation exits nonzero.
  Method: Run `node tests/web/run_browser_regression.mjs --base-url http://127.0.0.1:8060 --serve build/web --requirements REQ-015,REQ-016,REQ-017 --evidence build/web-evidence/local-e2e`, then `node tests/web/run_browser_regression.mjs --base-url https://seo077.github.io/block_siege/ --requirements REQ-015,REQ-016,REQ-017 --manifest build/web/build-manifest.json --evidence build/web-evidence/deployed-e2e`.
