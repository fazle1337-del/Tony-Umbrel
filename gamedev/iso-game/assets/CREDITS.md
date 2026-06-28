# Asset credits

## explorer.glb  (current player character)

- **Author:** Made for this project (procedurally modelled in Blender via
  blender-mcp; see `../../BLENDER_MCP.md`).
- **License:** CC0 / original work.
- **Description:** Low-poly, flat-shaded "triangle-shaped" explorer character
  (cone hat, faceted head, triangular body, backpack). Static mesh, not rigged.
- **Use here:** the player character (`main.gd` `PLAYER_MODEL`).

> Placeholder while we get the game working — to be replaced later with a nicer
> (ideally rigged/animated) character. The animation hook in `main.gd`
> (`_setup_animation`) is a no-op for this static mesh and will light up
> automatically once the model has Walk/Idle clips.
