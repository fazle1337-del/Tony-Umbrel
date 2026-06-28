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
| MCP config | `.mcp.json` (project scope) with `GODOT_PATH=/home/tony/.local/bin/godot` |

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

## Project layout

- `test-project/` — minimal Godot 4 project used to verify the toolchain.
  Run it with `godot --headless --path test-project`.
- New games: create a folder with its own `project.godot`. Keep one Godot
  project per subfolder so the MCP `projectPath` stays unambiguous.

## Conventions

- GDScript uses **tabs** for indentation (Godot's default; `.tscn`/`.gd` expect it).
- Target Godot 4.7 API. Don't use Godot 3.x syntax (e.g. `KinematicBody` →
  `CharacterBody2D/3D`, `yield` → `await`, `export var` → `@export var`).
