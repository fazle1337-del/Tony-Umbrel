# Game development workspace

Godot 4 game-dev workspace wired up for Claude Code, with the `godot-mcp` MCP
server so Claude can drive the engine directly (run projects, edit scenes,
capture debug output).

## Environment

| Piece | Value |
|---|---|
| Engine | Godot **4.7-stable** (GDScript / standard build) |
| Godot binary | `~/.local/bin/godot` (on PATH — `godot --version`) |
| MCP server | `godot` → `node ~/.local/share/godot-mcp/build/index.js` (Coding-Solo/godot-mcp) |
| MCP config | `.mcp.json` (project scope) — `godot` + `blender` servers |
| Blender | **4.2.9 LTS** → `~/.local/bin/blender` (3D asset pipeline) |
| `blender-mcp` | `blender` server via `~/.local/bin/uvx blender-mcp`; needs Blender open + addon started — see `BLENDER_MCP.md` |

> The repo root is `/home/tony/Gitea`; this workspace is the `gamedev/` subtree.

## Running Godot from the CLI

```bash
godot --version                       # check engine
godot --headless --path <project>     # run a project headless (CI / quick test)
godot --path <project> --editor       # open the editor on a project
godot --headless --path <project> --script res://some.gd   # run a single script
```

`--headless` is what to use for automated runs and tests — no window, output goes
to stdout, exit code reflects success.

## MCP server (`godot`)

Configured in `.mcp.json`. On a fresh session Claude Code will ask you to
**approve** this project-scoped server once (trust prompt) before its tools load.

Tools it provides: `run_project`, `stop_project`, `get_debug_output`,
`launch_editor`, `get_godot_version`, `list_projects`, `get_project_info`,
`create_scene`, `add_node`, `save_scene`, `load_sprite`, `get_uid`,
`update_project_uids`, `export_mesh_library`.

Smoke-test the server without Claude:

```bash
node ~/.local/share/godot-mcp/build/index.js   # should print "Godot MCP server running on stdio"
```

To rebuild after updating the server:

```bash
cd ~/.local/share/godot-mcp && git pull && npm install && npm run build
```

## 3D assets

- Place models as `.glb` under a project's `assets/` folder; record licensing in
  `assets/CREDITS.md` (only use CC0 / clearly-licensed assets).
- `iso-game/` uses the CC0 **RobotExpressive** character as a placeholder.
- To create custom models (incl. AI image→3D via Hyper3D Rodin), use Blender +
  `blender-mcp` — setup and workflow in **`BLENDER_MCP.md`**.

## Project layout

- `test-project/` — minimal Godot 4 project used to verify the toolchain.
  Run it with `godot --headless --path test-project`.
- `poc-game/` — "catch the falling blocks" 2D proof-of-concept. Smoke-tests the
  full pipeline (input, `_process`, `Area2D` collision/signals, `_draw`, UI).
  Headless self-test: `godot --headless --path poc-game -- --self-test`.
- `iso-game/` — the main game: isometric (real 3D + orthographic camera) with
  A* click-to-move pathfinding around obstacles. Has its own `CLAUDE.md` and a
  self-verification harness (see below). **Start here for game work.**
- New games: create a folder with its own `project.godot`. Keep one Godot
  project per subfolder so the MCP `projectPath` stays unambiguous.

## Self-verification harness (autonomy loop)

Game correctness is visual/feel-based, which an agent can't perceive natively.
The fix is to convert it into observable signals, so changes can be self-checked
without a human in the loop. `iso-game/` is the reference implementation:

- **Logic → headless tests.** Pure, stateless functions (e.g. coordinate/grid
  math, pathfinding) live in `scripts/` and are covered by `tests/test_*.gd`
  (`extends SceneTree`, assert, `quit(0|1)`). Run all via `tools/run_tests.sh`.
- **Visuals → deterministic screenshots.** A `--screenshot` cmdline flag renders
  a fixed frame to `screenshots/latest.png` then quits; `tools/screenshot.sh`
  wraps it (needs a display — defaults to `DISPLAY=:1` — since rendering can't
  run under `--headless`). Read the PNG to verify framing/layout/colour.
- **Determinism is the contract:** seeded RNG, fixed camera, fixed frame count —
  so two runs are comparable and regressions are visible.

> Tests don't load `main.tscn`/`main.gd`, so green tests don't prove the scene
> loads — always run the screenshot too after touching scene/UI code.

Apply this pattern to every new game and mechanic.

## Conventions

- GDScript uses **tabs** for indentation (Godot's default; `.tscn`/`.gd` expect it).
- Target Godot 4.7 API. Don't use Godot 3.x syntax (e.g. `KinematicBody` →
  `CharacterBody2D/3D`, `yield` → `await`, `export var` → `@export var`).
