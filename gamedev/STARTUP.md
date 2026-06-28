# Session startup wiki — Claude + Godot + Blender

Precise checklist for starting a work session in this workspace. Follow the
order exactly; ordering is what trips people up.

## TL;DR

1. **If doing 3D asset work:** start **Blender + its MCP server FIRST**.
2. **Then** start Claude Code in `~/Gitea/gamedev`.
3. Approve the project MCP servers when prompted; verify with `/mcp`.

> Godot-only work needs none of the Blender steps — skip to step 3.

---

## 0. What's already installed (reference — don't redo)

| Piece | Path / command |
|---|---|
| Godot 4.7 | `~/.local/bin/godot` |
| Blender 4.2.9 LTS | `~/.local/bin/blender` |
| `uv` / `uvx` | `~/.local/bin/uvx` |
| godot-mcp | `node ~/.local/share/godot-mcp/build/index.js` |
| blender-mcp addon | `~/.local/share/blender-mcp/addon.py` (already enabled in Blender) |
| MCP config | `~/Gitea/gamedev/.mcp.json` → servers: `godot`, `blender` |

## 1. Display (needed for Godot screenshots AND the Blender GUI)

Rendering can't run headless. This machine uses **`DISPLAY=:1`**.

```bash
echo $DISPLAY        # expect :1
```

The harness scripts (`tools/screenshot.sh`) default to `:1` already.

## 2. Start Blender + the BlenderMCP server  *(only for 3D asset work)*

**Order matters:** Blender's socket server must be running **before** Claude Code
launches, because `blender-mcp` connects at startup.

1. Launch Blender (GUI): `blender`
2. In the 3D viewport press **N** → **BlenderMCP** tab.
3. *(Optional, for AI text/image→3D)* tick **"Use Hyper3D Rodin 3D model
   generation"** and paste an API key.
   ⚠️ The bundled **free-trial key often has no credits** → `API_INSUFFICIENT_FUNDS`.
   Use your own funded Rodin key (from hyper3d.ai) for generation.
4. Click **"Connect to Claude" / "Start MCP Server"**.
5. Confirm in Blender's launch terminal:
   `BlenderMCP server started on localhost:9876`

The addon is already installed — **do not reinstall**. If it's somehow disabled:
Edit → Preferences → Add-ons → search "MCP" → re-enable.

## 3. Start Claude Code

```bash
cd ~/Gitea/gamedev && claude
```

- On first launch it prompts to **trust/approve** the project MCP servers
  (`godot`, `blender`). Approve.
- `blender-mcp` (`uvx blender-mcp`) then connects to Blender on `:9876`.

## 4. Verify

- `/mcp` → both `godot` and `blender` show **connected**.
- Godot: `godot --version`
- Blender link: ask Claude "get the blender scene info" or "blender viewport
  screenshot".

---

## Gotchas (exact)

- **Editing `.mcp.json` mid-session does nothing** until you restart Claude Code.
- **Start Blender's server BEFORE Claude Code.** If you start it after, the
  Blender tools won't connect — restart Claude Code.
- **Keep Blender open** with the server running the whole time you use Blender
  tools. Closing Blender drops the connection.
- **Godot needs no daemon** — godot MCP + CLI work standalone; only *screenshots*
  need `DISPLAY`.
- **Rodin free-trial key** = limited/zero balance. Funded key required for
  `generate_hyper3d_model_via_*`.

---

## iso-game verification loop (every change)

```bash
bash iso-game/tools/run_tests.sh     # logic tests, exits non-zero on failure
bash iso-game/tools/screenshot.sh    # -> iso-game/screenshots/latest.png
```

## Asset pipeline quick-ref (Blender → Godot)

1. Model/generate in Blender.
2. Export **glTF Binary (.glb)** to `iso-game/assets/`.
3. Set `PLAYER_MODEL` in `iso-game/main.gd`; tune `PLAYER_SCALE`.
4. `godot --headless --path iso-game --import`, then `tools/screenshot.sh`.

See also: `BLENDER_MCP.md` (Blender pipeline detail), `CLAUDE.md` (workspace),
`iso-game/CLAUDE.md` (the game).
