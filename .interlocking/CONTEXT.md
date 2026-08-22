# CONTEXT — Block Siege

## Principles

- Preserve deterministic, readable turn-state transitions around firing, physics resolution, ownership transfer, and round changes.
- Treat physical displacement and rotation as gameplay rules: falling is measured from each block's captured baseline.
- Keep the prototype playable as a local two-player game with keyboard and mouse controls.
- Prefer Godot-native scenes, resources, and GDScript; the Web export is the submission target.
- Keep the detailed game rules and unresolved design decisions in `block-siege-design.md` rather than duplicating them here.

## Stack and constraints

- Godot 4 project using GDScript and a single `Node3D` main scene.
- Runtime source lives in `scripts/`; `main.tscn` loads `scripts/main.gd`.
- Rendering uses the `gl_compatibility` backend for desktop/mobile compatibility.
- The configured Web export writes to `build/web/index.html`.
- No automated test suite is present.
- No Godot executable is available in the current development shell, so engine execution and export cannot currently be used as verification commands.
- The project directory is not currently recognized as a Git worktree.

## Glossary

Domain words that mean something specific here.

| Term | Means |
|---|---|
| BL | The game's block-length unit used for field dimensions, movement, and construction. |
| Siege block | A physical `RigidBody3D` block that can belong to a player, form an object, or act as ammunition. |
| Fortress | A player's primary block structure; its collapse can determine victory. |
| Catapult | Weapon index 0, a higher-arc launcher assembled from blocks. |
| Tank | Weapon index 1, a lower-arc movable weapon assembled from blocks. |
| Reserve | A player's unplaced block supply, including blocks recovered through combat resolution. |
| Baseline | A block's recorded transform used to decide whether it has fallen. |
| Resolution | The post-shot interval that waits for physics to settle, then applies destruction, capture, and victory rules. |
| Complete destruction | All blocks belonging to a weapon or fortress satisfy the fall test during resolution. |

## Roadmap

- [ ] E1 Core combat and closed-economy vertical slice → work/001-core-combat-economy
- [ ] E2 Turn actions and weapon constraints
- [ ] E3 Setup, construction, and fortress rebuilding
- [ ] E4 Submission UX and Web readiness

Dependencies: E1 → E2 → E3 → E4. The maintained game design and open-question backlog lives in `block-siege-design.md`.

## Completed

- Initial Godot prototype: field, two-player armies, firing, physics settling, destruction resolution, turn changes, and a 20-round limit.
