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
  Judged: Cannot currently be judged by reading and running: `tests/web/run_browser_regression.mjs` does not exist. Once supplied, the standard command must exit 0 only when source and exported text decode as UTF-8 and the actual browser HUD strings exactly match the approved SPEC oracle character-for-character, contain neither U+FFFD nor known UTF-8-to-legacy corruption patterns, expose all required bridge fields, and write `build/web-evidence/local/result.json` plus a PNG screenshot; an injected source, export, or runtime mismatch must make it exit nonzero.
  Method: `node tests/web/run_browser_regression.mjs --base-url http://127.0.0.1:8060 --serve build/web --requirements REQ-012,REQ-013 --evidence build/web-evidence/local`

REQ-013
  Judged: Cannot currently be judged by reading and running: `tests/web/run_browser_regression.mjs` does not exist. Once supplied, fresh-game browser cases sending real canvas press/move/release events must show no shot below 24 px, exactly one shot at 24 px and above, same-sign horizontal aiming change, increased elevation for upward drag, strictly increasing impulse for 40/120/240 px, and equivalent opponent-facing semantics for both players; bridge evidence must include received coordinates, shot ID/count, initial velocity, impulse, normalized direction, active player, and ready-to-resolving state, with any violated case exiting nonzero.
  Method: `node tests/web/run_browser_regression.mjs --base-url http://127.0.0.1:8060 --serve build/web --requirements REQ-012,REQ-013 --evidence build/web-evidence/local`

REQ-014
  Judged: Cannot currently be judged by reading and running: the browser harness and `build/web/build-manifest.json` do not exist, and live deployment additionally requires network access. Once supplied and deployed from master, the standard command must exit 0 only when the live URL loads a game canvas and exact Korean HUD, a real canvas drag creates one measured shot and changes ready to resolving, the live manifest source commit and every relative asset SHA-256 match the approved local build, the Pages workflow succeeded, and JSON evidence records URL, commit, hash comparisons, HUD, pointer/shot telemetry, workflow result, and PNG path; stale/tampered assets must exit nonzero.
  Method: `node tests/web/run_browser_regression.mjs --base-url https://seo077.github.io/block_siege/ --requirements REQ-012,REQ-013,REQ-014 --manifest build/web/build-manifest.json --evidence build/web-evidence/deployed`
