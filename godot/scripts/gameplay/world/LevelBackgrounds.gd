class_name LevelBackgrounds
extends RefCounted
## Registry of real background textures per level id, replacing the flat
## grey ground the greybox phase used. Ported from src/game/levels.ts's
## `background` imports (each level's full pre-rendered scene image, not a
## tileset — confirmed by reading the actual level data and checking pixel
## dimensions against LevelData.width/height before assuming; see
## docs/migration/ASSET_INVENTORY.md and MIGRATION_MATRIX.md "Assety").
##
## Paths listed explicitly (ItemRegistry.gd pattern) rather than scanned at
## runtime. Filled in one level at a time — a level missing here just gets
## no background (LevelRuntime skips it), not an error, since obstacle/item/
## goal placement (already `Rect2` world coordinates, unchanged) doesn't
## depend on a background existing.
const _PATHS := {
	"1": "res://assets/textures/environment/waly-merged.jpeg",
	"2": "res://assets/textures/environment/park-merged.jpeg",
	"3": "res://assets/textures/environment/alley-merged.jpeg",
	"4": "res://assets/textures/environment/level-attic.jpg",
	"5": "res://assets/textures/environment/level-garden.jpg",
	"6": "res://assets/textures/environment/lu.jpeg",
}

## Level 7 ("Salon") has no single pre-rendered background image like L1-6 —
## it's the first level using a real modular tileset (Kenney-style
## `TopDownHouse_FloorsAndWalls.png`, user-provided per plan31-08.md
## "Assety graficzne") instead of a full-scene painting. `FloorsAndWalls.png`
## turned out to be a style-preview sheet, not a granular grid tileset (each
## swatch is a whole seamless material block, not individually-packed small
## tiles — confirmed by cropping and visually inspecting several swatches
## before committing to coordinates, not guessed) — so the "floor" here is
## one verified-tileable swatch region, stamped across the level at its
## native resolution rather than stretched like the single-image
## backgrounds, keeping the pixel-art crisp instead of blurry.
const TILED_FLOOR_TEXTURE_PATH := "res://assets/textures/interior/TopDownHouse_FloorsAndWalls.png"
const TILED_FLOOR_TILE_RECT := Rect2i(160, 92, 32, 32) # wood-plank floor swatch, verified seamless

static func texture_for(level_id: String) -> Texture2D:
	if level_id == "7":
		return null # handled by tiled_floor_for() instead — see LevelRuntime._setup_background()
	if not _PATHS.has(level_id):
		return null
	return load(_PATHS[level_id])

## Crops just the verified-tileable 32x32 swatch region out of the
## style-preview sheet into its own small texture — shared by both
## `build_floor_tileset()` (real TileSet path) and the historical
## `tiled_floor_for()` baked-Image path below.
static func _get_floor_tile_texture() -> ImageTexture:
	var tile_sheet := load(TILED_FLOOR_TEXTURE_PATH) as Texture2D
	var tile_img := tile_sheet.get_image()
	var tile := Image.create(TILED_FLOOR_TILE_RECT.size.x, TILED_FLOOR_TILE_RECT.size.y, false, Image.FORMAT_RGBA8)
	tile.blit_rect(tile_img, TILED_FLOOR_TILE_RECT, Vector2i.ZERO)
	return ImageTexture.create_from_image(tile)

## Real TileSet, built at runtime (not hand-authored as a .tres — a
## TileSetAtlasSource pointed at the full style-preview sheet would need
## precise margin/separation math to isolate just one 32x32 swatch among
## its irregular layout; building a TileSet from the already-cropped
## single-tile texture instead sidesteps that entirely, since the source
## texture IS exactly one tile). "Principal lead" review (plan31-08.md,
## point 2) flagged the previous tiled_floor_for()-only approach as a
## baked-ImageTexture workaround: one full-level-sized bitmap in memory per
## level, unpaintable in the editor, no per-tile collision-layer hook. A
## real TileSet fixes all three — texture memory is one 32x32 tile
## regardless of room size, `LevelRuntime` paints it as a `TileMapLayer`
## (editor-paintable structure, even though this level still paints its
## cells in a code loop rather than by hand), and a physics layer can be
## added later without restructuring anything.
static func build_floor_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILED_FLOOR_TILE_RECT.size

	var source := TileSetAtlasSource.new()
	source.texture = _get_floor_tile_texture()
	source.texture_region_size = TILED_FLOOR_TILE_RECT.size
	source.create_tile(Vector2i.ZERO)

	tile_set.add_source(source)
	return tile_set

## Composes a level.width x level.height ImageTexture by stamping
## TILED_FLOOR_TILE_RECT repeatedly. Superseded by build_floor_tileset() +
## TileMapLayer for LevelRuntime's actual background (see
## "Principal lead" review, point 2) — kept only as a documented fallback,
## not called from anywhere in this codebase anymore.
static func tiled_floor_for(width: int, height: int) -> ImageTexture:
	var tile := _get_floor_tile_texture().get_image()
	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var tw := TILED_FLOOR_TILE_RECT.size.x
	var th := TILED_FLOOR_TILE_RECT.size.y
	var y := 0
	while y < height:
		var x := 0
		while x < width:
			out.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(x, y))
			x += tw
		y += th
	return ImageTexture.create_from_image(out)
