# TASKS — 001-core-combat-economy

<!--
  APPEND ONLY. When verification fails, add a NEW task and set the original back
  to `blocked` — never rewrite it. One task = one commit.
-->

## T-001 Introduce the player-list match model and fixed scenario

- state:    todo
- covers:   REQ-001, REQ-002
- depends:  —
- produces: |
    scripts/core/block_record.gd
      class_name BlockRecord
      static func create(p_id: int, p_owner_id: int, p_location: StringName, p_object_id: int, p_is_ammo: bool = false) -> BlockRecord
    scripts/core/weapon_state.gd
      class_name WeaponState
      static func create(p_id: int, p_owner_id: int, p_kind: StringName, p_structure_block_ids: Array[int], p_ammo_block_id: int) -> WeaponState
      func can_fire() -> bool
    scripts/core/player_state.gd
      class_name PlayerState
      static func create(p_id: int, p_reserve_block_ids: Array[int], p_fortress_block_ids: Array[int], p_weapons: Array[WeaponState]) -> PlayerState
      func find_weapon(weapon_id: int) -> WeaponState
    scripts/core/match_state.gd
      class_name MatchState
      static func create_fixed_scenario(player_ids: Array[int] = [1, 2]) -> MatchState
      static func create_from_players(p_players: Array[PlayerState], p_blocks: Dictionary) -> MatchState
      func get_player(player_id: int) -> PlayerState
      func total_block_count() -> int
      func validate_ledger() -> Dictionary
    tests/regression_runner.gd
      func run_requirement(requirement: String) -> bool
    tests/fixtures/fixed_scenario.gd
      static func build(player_ids: Array[int] = [1, 2]) -> MatchState
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-001 && godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-002

## T-002 Bind the fixed scenario model to scene bodies

- state:    todo
- covers:   REQ-001, REQ-002
- depends:  T-001
- produces: |
    scripts/siege_block.gd
      func setup(p_block_id: int, p_owner_id: int, p_object_id: int, color: Color, frozen_block: bool = false, p_is_ammo: bool = false) -> void
      func apply_record(record: BlockRecord) -> void
    scripts/main.gd
      func create_match(p_player_ids: Array[int] = [1, 2]) -> void
      func spawn_match_bodies(state: MatchState) -> void
      func body_for_block(block_id: int) -> SiegeBlock
      func sync_body_poses_to_model() -> void
    tests/fixtures/fixed_scenario_scene.gd
      static func assert_scene_binding(main: Node) -> bool
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-001

## T-003 Implement guarded one-shot firing

- state:    todo
- covers:   REQ-003, REQ-009
- depends:  T-001, T-002
- produces: |
    scripts/core/match_state.gd
      func request_fire(player_id: int, weapon_id: int, drag: Vector2) -> Dictionary
      func can_accept_combat_input() -> bool
    scripts/main.gd
      func fire_weapon(player_id: int, weapon_id: int, drag: Vector2) -> bool
      func spawn_projectile(block_id: int, origin: Vector3, impulse: Vector3) -> SiegeBlock
    tests/fixtures/firing_cases.gd
      static func cases() -> Array[Dictionary]
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-003

## T-004 Add fixed-tick stability and timeout adjudication

- state:    todo
- covers:   REQ-004
- depends:  T-003
- produces: |
    scripts/core/resolution_state.gd
      class_name ResolutionState
      const MINIMUM_SECONDS := 0.8
      const QUIET_SECONDS := 0.6
      const TIMEOUT_SECONDS := 8.0
      static func begin(shot_block_id: int, target_block_ids: Array[int]) -> ResolutionState
      func advance_fixed_tick(delta: float, motions: Dictionary) -> StringName
      func retry() -> void
    scripts/main.gd
      func collect_resolution_motion() -> Dictionary
      func advance_resolution(delta: float) -> void
    tests/fixtures/stability_cases.gd
      static func cases() -> Array[Dictionary]
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-004

## T-005 Record per-block baselines and classify collapse

- state:    todo
- covers:   REQ-005
- depends:  T-002, T-004
- produces: |
    scripts/core/block_record.gd
      func capture_baseline(p_transform: Transform3D) -> void
      func is_fallen_at(p_transform: Transform3D, short_edge: float = 0.2) -> bool
    scripts/core/weapon_state.gd
      func is_destroyed(blocks: Dictionary, poses: Dictionary) -> bool
    scripts/core/player_state.gd
      func is_fortress_destroyed(blocks: Dictionary, poses: Dictionary) -> bool
    scripts/siege_block.gd
      func capture_baseline() -> void
      func is_fallen() -> bool
    tests/fixtures/collapse_cases.gd
      static func cases() -> Array[Dictionary]
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-005

## T-006 Apply shot outcomes as one idempotent ledger transaction

- state:    todo
- covers:   REQ-006, REQ-007
- depends:  T-001, T-003, T-005
- produces: |
    scripts/core/resolution_transaction.gd
      class_name ResolutionTransaction
      static func build(state: MatchState, poses: Dictionary) -> ResolutionTransaction
      func apply(state: MatchState) -> Dictionary
      func affected_block_ids() -> Array[int]
    scripts/core/match_state.gd
      func resolve_shot_once(poses: Dictionary) -> Dictionary
      func ownership_snapshot() -> Dictionary
      func validate_ledger() -> Dictionary
    tests/fixtures/resolution_cases.gd
      static func cases() -> Array[Dictionary]
    tests/fixtures/ledger_cases.gd
      static func cases() -> Array[Dictionary]
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-006 && godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-007

## T-007 Implement ordered turns, fortress victory, and round-20 scoring

- state:    todo
- covers:   REQ-008
- depends:  T-001, T-006
- produces: |
    scripts/core/match_state.gd
      func request_end_turn(player_id: int) -> Dictionary
      func adjudicate_fortress_victory(attacker_id: int, poses: Dictionary) -> Dictionary
      func adjudicate_round_limit() -> Dictionary
      func result_snapshot() -> Dictionary
    tests/fixtures/turn_and_victory_cases.gd
      static func cases() -> Array[Dictionary]
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-008

## T-008 Preserve and retry timed-out shots exactly once

- state:    todo
- covers:   REQ-004, REQ-009
- depends:  T-004, T-006, T-007
- produces: |
    scripts/core/resolution_snapshot.gd
      class_name ResolutionSnapshot
      static func capture(state: MatchState, poses: Dictionary, motions: Dictionary) -> ResolutionSnapshot
      func restore_into(state: MatchState) -> Dictionary
      func equals_runtime(state: MatchState, poses: Dictionary, motions: Dictionary) -> bool
    scripts/core/match_state.gd
      func enter_timeout(poses: Dictionary, motions: Dictionary) -> void
      func retry_timed_out_shot() -> Dictionary
      func resolution_apply_count() -> int
    scripts/main.gd
      func freeze_timeout_bodies() -> void
      func retry_resolution() -> bool
    tests/fixtures/retry_cases.gd
      static func cases() -> Array[Dictionary]
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-009

## T-009 Integrate core state transitions with the playable scene

- state:    todo
- covers:   REQ-003, REQ-004, REQ-006, REQ-008, REQ-009
- depends:  T-002, T-003, T-004, T-005, T-006, T-007, T-008
- produces: |
    scripts/main.gd
      func apply_resolution_result(result: Dictionary) -> void
      func remove_transferred_bodies(block_ids: Array[int]) -> void
      func end_turn() -> void
      func set_interaction_enabled(enabled: bool) -> void
      func current_adjudication_state() -> StringName
    main.tscn
      BlockSiege Node3D remains the playable main scene backed by MatchState
- verify:   godot4 --headless --path . --quit-after 10

## T-010 Expose adjudication and conservation diagnostics in the UI

- state:    todo
- covers:   REQ-009, REQ-010
- depends:  T-008, T-009
- produces: |
    scripts/main.gd
      func update_ui(message: String = "") -> void
      func diagnostic_text() -> String
      func on_retry_pressed() -> void
    main.tscn
      HUD exposes adjudication state, independently counted block total, timeout error, and Retry control
    tests/fixtures/ui_diagnostics.gd
      static func assert_diagnostics(main: Node) -> bool
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010

## T-011 Complete the repeatable headless regression suite

- state:    todo
- covers:   REQ-001, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008, REQ-009, REQ-010
- depends:  T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010
- produces: |
    tests/regression_runner.gd
      func parse_arguments(arguments: PackedStringArray) -> Dictionary
      func run_requirement(requirement: String) -> bool
      func run_all(repeat_count: int = 1) -> bool
      func report_failure(requirement: String, fixture: String, detail: String) -> void
    tests/fixtures/full_regression.gd
      static func scenarios() -> Array[Dictionary]
    README.md
      Documents Godot 4 headless requirement and full-suite commands
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010 --repeat 2

## Execution log

- 2026-08-24: T-001 done at `149b54d`; REQ-001 and REQ-002 headless verification passed with Godot 4.7.2.
- 2026-08-24: T-002 done at `106eae4`; fixed-scenario scene binding passed REQ-001 and REQ-002 headless verification.
- 2026-08-24: T-003 done at `30d23ab`; fixture-driven guarded firing passed REQ-001, REQ-002, and REQ-003 headless verification.
- 2026-08-24: T-004 done at `7b79111`; fixed-tick thresholds, quiet persistence/reset, exact timeout, and retry timers passed REQ-004 verification.
- 2026-08-24: T-005 done at `448f0f6`; per-block baseline, collapse boundaries, full-destruction, and ammo exclusion passed REQ-005 verification.
- 2026-08-24: T-006 done at `a83f6aa`; atomic rollback, idempotent outcomes, and generic conserved-ID ledger passed REQ-006/REQ-007 verification.
- 2026-08-24: T-007 done at `8155410`; ordered multi-player turns, fortress victory, and round-20 scoring passed REQ-008 verification.
- 2026-08-24: T-008 done at `af2fee0`; frozen timeout snapshots, repeated retries, and exactly-once eventual resolution passed REQ-009 verification.
- 2026-08-24: T-009 done at `7e961a8`; playable scene transitions were bound to MatchState and passed smoke plus REQ-001 through REQ-009.
- 2026-08-24: T-010 done at `3282af9`; HUD adjudication state, conserved total, timeout error, and Retry control passed REQ-010 UI diagnostics.
- 2026-08-24: T-011 done at `2d6b45c`; individual REQ checks, aggregate acceptance matrix repeated twice, and scene smoke all passed.

## T-012 Gate resolution callbacks on settled adjudication

- state:    todo
- covers:   REQ-009
- depends:  T-008, T-011
- produces: |
    scripts/core/match_state.gd
      Explicit settled-resolution authorization that rejects early or duplicate callbacks
    scripts/main.gd
      Authorizes model resolution only after fixed-tick adjudication reports resolved
    tests/regression_runner.gd
      Resolving-state callback spam fixture plus successful exactly-once settled resolution
- verify:   godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-009

## Execution log (continued)

- 2026-08-24: Independent acceptance verification found REQ-009 vulnerable to premature resolving-state callbacks; T-012 added as corrective work. REQ-010 remained inconclusive pending executable and human UI observation.
- 2026-08-24: T-012 done at `1822ea7`; resolving-state callback spam is inert and settled resolution applies exactly once. REQ-009 and the full matrix repeated twice passed.

## T-013 Verify complete play-scene UI state and Retry behavior

- state:    todo
- covers:   REQ-011
- depends:  T-010, T-012
- produces: |
    tests/fixtures/ui_diagnostics.gd
      static func assert_diagnostics(main: Node) -> bool
      Asserts initial, resolving, and timeout labels/totals against independent scene and ledger counts, then Retry preserves the shot ID and immediately refreshes the visible state
    tests/regression_runner.gd
      REQ-010-UI instantiates the playable `main.tscn` scene for the REQ-011 fixture
- verify:   .\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010-UI

## Execution log (continued)

- 2026-08-24: T-013 done at `98f8c8e`; the actual `main.tscn` scene passed initial/resolving/timeout state and independent 200-count checks, and Retry preserved shot ID 10 while immediately refreshing the HUD. REQ-010-UI and REQ-010 repeated twice passed.

## T-014 Fix UTF-8 HUD strings and deterministic drag launch semantics

- state:    todo
- covers:   REQ-012, REQ-013
- depends:  T-013
- produces: |
    scripts/main.gd
      const APPROVED_KOREAN_STRINGS: PackedStringArray
      func launch_solution(player_index: int, weapon_index: int, drag: Vector2) -> Dictionary
      func web_test_snapshot() -> Dictionary
      Rejects drags shorter than 24 px and maps camera-relative lateral/elevation plus monotonic 40/120/240 px impulse
    tests/regression_runner.gd
      REQ-012 and REQ-013 headless string/launch boundary verification
- verify:   .\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-012

## T-015 Add the real-browser CDP regression harness and Godot Web bridge

- state:    todo
- covers:   REQ-012, REQ-013
- depends:  T-014
- produces: |
    scripts/main.gd
      globalThis.__BLOCK_SIEGE_TEST__.snapshot() and reset() read-only Web bridge
    tests/web/run_browser_regression.mjs
      Dependency-free Node 24 CDP runner with local static server, real canvas pointer cases, JSON evidence, and PNG screenshots
- verify:   node tests/web/run_browser_regression.mjs --base-url http://127.0.0.1:8060 --serve build/web --requirements REQ-012,REQ-013 --evidence build/web-evidence/local

## T-016 Export, manifest, deploy, and verify the approved Web build

- state:    todo
- covers:   REQ-014
- depends:  T-015
- produces: |
    build/web/**
      Current Godot Web export
    build/web/build-manifest.json
      source_commit and SHA-256 for every deployed target asset
    .github/workflows/pages.yml
      Existing Pages workflow deploys the manifest-bearing build
- verify:   node tests/web/run_browser_regression.mjs --base-url https://seo077.github.io/block_siege/ --requirements REQ-012,REQ-013,REQ-014 --manifest build/web/build-manifest.json --evidence build/web-evidence/deployed

## Execution log (continued)

- 2026-08-24: T-014 done at `8767c21`; UTF-8 Korean oracle/runtime strings and deterministic 24px drag boundary, camera-relative direction, elevation, and monotonic impulse passed REQ-012, REQ-013, REQ-003, and REQ-010-UI.
- 2026-08-25: T-015 done at `e16602f`; bundled Noto Sans KR renders without tofu, and the dependency-free CDP harness passed 11 isolated real-canvas cases with missing-glyph, HUD, pointer, launch, JSON, and PNG evidence.
- 2026-08-25: T-016 done at `cb87a97`; GitHub Pages workflow run 32743643892 succeeded, the deployed manifest matched all 10 approved asset hashes, and 11 live Chrome canvas cases passed REQ-012 through REQ-014 with visually inspected Korean HUD evidence.
- 2026-08-25: Independent verification of `af88318..fb2399b` returned 13 PASS and REQ-014 FAIL because one deployed run exhausted the 6.4-second bridge startup window before running any browser case; added T-017 without rewriting T-016.

## T-017 Make deployed browser startup resilient to normal WebAssembly load variance

- state:    todo
- covers:   REQ-014
- depends:  T-016
- produces: |
    tests/web/run_browser_regression.mjs
      async function freshPage(cdp, baseUrl)
      Waits a bounded, diagnostic-rich interval suitable for cold deployed WebAssembly startup while preserving nonzero failure for a genuinely absent canvas/bridge
- verify:   node tests/web/run_browser_regression.mjs --base-url https://seo077.github.io/block_siege/ --requirements REQ-012,REQ-013,REQ-014 --manifest build/web/build-manifest.json --evidence build/web-evidence/deployed

## Execution log (continued)

- 2026-08-25: T-017 done at `622afa5`; bounded readiness polling increased to 30 seconds with URL/document/canvas/bridge diagnostics, absent bridges still fail nonzero, and the exact live REQ-014 command passed all 11 cases.

## T-018 Implement playable catapult range and bounded normal resolution

- state:    todo
- covers:   REQ-015, REQ-016
- depends:  T-017
- produces: |
    scripts/main.gd
      func launch_solution(player_index: int, weapon_index: int, drag: Vector2) -> Dictionary
      func stop_projectile_outside_field() -> bool
      Full-power catapult reaches the opposing deployment boundary; out-of-field projectiles stop and settle; post-resolution HUD advertises Enter
    tests/regression_runner.gd
      REQ-015 trajectory/range fixtures and REQ-016 boundary-stop/resolution/input/HUD fixtures
- verify:   .\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-015

## T-019 Extend the browser bridge and harness through resolved Enter turn transition

- state:    todo
- covers:   REQ-017
- depends:  T-018
- produces: |
    scripts/main.gd
      func web_test_snapshot() -> Dictionary
      Exposes projectile position/time samples, round, camera orientation, and interaction state
    tests/web/run_browser_regression.mjs
      Local and deployed E2E case sends real 240px drag, blocked pre-resolution Enter, waits for resolving-to-ready, then sends Enter and proves player 2/round 1/HUD/camera/input
- verify:   node tests/web/run_browser_regression.mjs --base-url http://127.0.0.1:8060 --serve build/web --requirements REQ-015,REQ-016,REQ-017 --evidence build/web-evidence/local-e2e

## T-020 Export, deploy, and verify the playable-turn Web build

- state:    todo
- covers:   REQ-014, REQ-017
- depends:  T-019
- produces: |
    build/web/**
      Current Godot Web export containing T-018/T-019
    build/web/build-manifest.json
      Approved source commit and SHA-256 for all deployed assets
- verify:   node tests/web/run_browser_regression.mjs --base-url https://seo077.github.io/block_siege/ --requirements REQ-015,REQ-016,REQ-017 --manifest build/web/build-manifest.json --evidence build/web-evidence/deployed-e2e

## Execution log (continued)

- 2026-08-25: T-018 done at `060df7f`; both-player 40/120/240 range progression, full-power opposing-zone reach, all field boundary stops, exactly-once normal resolution, resolving Enter lock, and ready HUD guidance passed REQ-015/016.
- 2026-08-25: T-019 done at `86ee66e`; measured projectile-only spin was corrected with physical angular damping/friction, and repeated real Chrome runs passed opposing-zone reach, no timeout, resolving Enter lock, ready transition, and exactly-once player-2 turn change.
- 2026-08-25: T-020 done at `9f27abc`; Pages workflow 32755631110 succeeded, live manifest source was 86ee66e, and deployed Chrome evidence passed 11 legacy cases plus 182-sample reach/resolution/Enter lifecycle with a visually confirmed player-2 ready HUD.
