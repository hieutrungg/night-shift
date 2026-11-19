class_name GameConfig
extends RefCounted
## Fixed game rules shared by every system. Change numbers only here.

## Hard design rule: a match always has 2 to 4 players, host included.
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4

const DEFAULT_PORT: int = 7777

const DEFAULT_LOCALE: String = "en"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "vi"]
