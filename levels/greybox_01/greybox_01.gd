extends GreyboxLevel
## Greybox 01: one-floor office block, 12 rooms around a central corridor,
## parking lot with the van at the bottom; the mannequin starts in the
## top-right room. Bulky loot (B) waits in the archive, top-left, which is
## as far from the entrance as the showroom. Legend: see greybox_level.gd.

const LAYOUT: PackedStringArray = [
	"#####################################",
	"#i......#.......#...#.......#......i#",
	"#.B.....#...i...#.L.#.......#...M...#",
	"#...L...#...L...D...D...L...#...L...#",
	"#.......D.......#...#....i..D.......#",
	"#..iB...#.......#...#.......#....i..#",
	"#.......#......i#...#.......#.......#",
	"####D############...############D####",
	"#.......#.......#...#.......#.......#",
	"#...L...#..i....#.L.#...L...#...L...#",
	"#....i..D...L...D...D.......D.......#",
	"#.......#.......#...#..i....#..i....#",
	"#.......#.......#...#.......#.......#",
	"############D####...####D############",
	"#.......#.......#...#.......#.......#",
	"#...L...#.......#.L.#...L...#...L...#",
	"#i......D...L...#...#.......D......i#",
	"#.......#.......D...D.......#.......#",
	"#.......#..i....#...#....i..#.......#",
	"#.......#.......#...#.......#.......#",
	"##################D##################",
	",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,PP,PP,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,,,,,,,,,VVVV,,,,,,,",
	",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
]

const ITEM_POOL: Array[ItemData] = [
	preload("res://features/items/data/radio.tres"),
	preload("res://features/items/data/lamp.tres"),
	preload("res://features/items/data/laptop.tres"),
	preload("res://features/items/data/toaster.tres"),
	preload("res://features/items/data/blender.tres"),
	preload("res://features/items/data/speaker.tres"),
	preload("res://features/items/data/books.tres"),
]

const BULKY_POOL: Array[ItemData] = [
	preload("res://features/items/data/crt_tv.tres"),
	preload("res://features/items/data/mini_fridge.tres"),
]


func _get_layout() -> PackedStringArray:
	return LAYOUT


func _get_item_pool() -> Array[ItemData]:
	return ITEM_POOL


func _get_decor() -> Array[Array]:
	return Greybox01Decor.ENTRIES


func _get_bulky_pool() -> Array[ItemData]:
	return BULKY_POOL
