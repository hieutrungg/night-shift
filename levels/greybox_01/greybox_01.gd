extends GreyboxLevel
## Greybox 01: one-floor office block, 12 rooms around a central corridor,
## parking lot with the van at the bottom; the mannequin starts in the
## top-right room. Legend: see greybox_level.gd.

const LAYOUT: PackedStringArray = [
	"#####################################",
	"#i......#.......#...#.......#......i#",
	"#.......#...i...#.L.#.......#...M...#",
	"#...L...#...L...D...D...L...#...L...#",
	"#.......D.......#...#....i..D.......#",
	"#..i....#.......#...#.......#....i..#",
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
	preload("res://features/items/data/toolbox.tres"),
	preload("res://features/items/data/lamp.tres"),
	preload("res://features/items/data/vase.tres"),
]


func _get_layout() -> PackedStringArray:
	return LAYOUT


func _get_item_pool() -> Array[ItemData]:
	return ITEM_POOL
