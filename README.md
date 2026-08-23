# Block Siege — Godot 4 prototype

Block Siege is a local two-player vertical slice covering physical firing, collapse adjudication, chained destruction, turn order, and the round-20 result.

## Run locally

Open the editor, then press F5:

```powershell
.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --editor --path .
```

Run the desktop game:

```powershell
.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path .
```

Run one headless requirement:

```powershell
.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-001
```

Run the complete acceptance matrix twice (REQ-010):

```powershell
.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010 --repeat 2
```

Run the full suite directly, or the smoke suite:

```powershell
.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/regression_runner.gd -- --all
.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit-after 2
```

For manual REQ-010 observation, run the desktop game and confirm adjudication status and the independent block total remain visible, and that timeout error/retry controls appear when a shot times out.

## Web export

Install the matching Godot export templates first; export is unavailable without them. This documentation does not assert that a Web build already exists.

```powershell
.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release Web build/web/index.html
```

Serve the result over HTTP; do not open `index.html` using a `file://` URL:

```powershell
python -m http.server 8000 --directory build/web
```

Open `http://localhost:8000/`.

The committed Web build is deployed through GitHub Pages at:

`https://seo077.github.io/block_siege/`

Pushing changes under `build/web/` to `master` triggers the Pages workflow.

## Controls

- `1`: select the active player's catapult
- `2`: select the active player's tank
- Left-mouse drag: choose firing direction and strength
- `WASD`: move the selected tank
- `Enter`: end the turn
