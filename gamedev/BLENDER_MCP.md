# Blender + blender-mcp (3D asset pipeline)

Set up so Claude can drive Blender for modelling and AI image/text→3D, then
export `.glb` into a game (e.g. to replace the placeholder character in
`iso-game/`). **The server side is already installed**; the Blender-side steps
below are interactive and only need doing once.

## What's installed (done)

| Piece | Location |
|---|---|
| Blender | **4.2.9 LTS** → `~/.local/bin/blender` (on PATH — `blender --version`) |
| `uv`/`uvx` | `~/.local/bin/uvx` (runs the MCP server) |
| blender-mcp server | launched via `uvx blender-mcp` (auto-fetched from PyPI) |
| blender-mcp addon | `~/.local/share/blender-mcp/addon.py` (Coding by Siddharth Ahuja) |
| MCP config | `.mcp.json` → `blender` server (project scope) |

## One-time Blender-side setup (you do this)

1. Open Blender: `blender` (needs a display; this box uses `DISPLAY=:1`).
2. **Edit → Preferences → Add-ons → Install from Disk…**, choose
   `~/.local/share/blender-mcp/addon.py`, then tick **Interface: Blender MCP**
   to enable it.
3. In the 3D viewport press **N** to open the sidebar → **BlenderMCP** tab.
4. (Optional) Toggle integrations in that tab:
   - **PolyHaven** — free HDRIs/textures/models.
   - **Hyper3D Rodin** — text/image→3D generation. Needs an API key (free trial
     key in the panel, or your own from hyper3d.ai). **This is the "model from a
     picture" feature.**
5. Click **Connect to Claude / Start MCP Server** (starts a socket on port 9876).

## Using it

- Blender must be **open with the server started** for the `blender` MCP tools to
  work. On a fresh Claude Code session you'll be asked to approve the project
  `blender` server once.
- Smoke-test the server alone (will report "Failed to connect to Blender" until
  step 5 above is done — that's expected):
  ```bash
  uvx blender-mcp
  ```

## Headless scripting (no MCP, available now)

For procedural/scripted modelling Claude can drive Blender directly, no GUI:
```bash
blender --background --python your_script.py    # runs bpy, exports glb, quits
```

## Workflow to replace the iso-game character

1. Generate/model in Blender (Rodin from a reference image, or scripted).
2. Export **glTF Binary (.glb)** to `iso-game/assets/`.
3. Point `PLAYER_MODEL` in `iso-game/main.gd` at the new file; tune
   `PLAYER_SCALE`.
4. `godot --headless --path iso-game --import`, then `tools/screenshot.sh` to
   verify in-engine.
