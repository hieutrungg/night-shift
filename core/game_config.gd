class_name GameConfig
extends RefCounted
## Fixed game rules shared by every system. Change numbers only here.

## Hard design rule: a match always has 2 to 4 players, host included.
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4

const DEFAULT_PORT: int = 7777

## How far (m, from the player's feet) the host accepts a door or item request.
## Longer than the interact ray to absorb network lag.
const INTERACT_MAX_DISTANCE: float = 3.5

## Round rules.
const ROUND_DURATION_SEC: float = 300.0
## Share of the spawned loot value the team must bring back to the van.
const QUOTA_RATIO: float = 0.5
## Quotas are rounded to this step so they read nicely.
const QUOTA_STEP: int = 10

const DEFAULT_LOCALE: String = "en"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "vi"]
