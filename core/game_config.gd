class_name GameConfig
extends RefCounted
## Fixed game rules shared by every system. Change numbers only here.

## Hard design rule: an online match always has 2 to 4 players, host included.
## Solo mode is separate and fully offline (Net.start_solo); it never relaxes this.
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

## The monster stays still this long after a round starts, so players can get inside.
const MONSTER_WAKE_DELAY_SEC: float = 20.0

## Solo mode tuning: one person must both watch the mannequin and carry loot.
const SOLO_QUOTA_RATIO: float = 0.35
const SOLO_MONSTER_SPEED_SCALE: float = 0.75
const SOLO_MONSTER_WAKE_DELAY_SEC: float = 30.0

const DEFAULT_LOCALE: String = "en"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "vi"]

## Physics layer bits (see layer_names in project.godot). The mannequin only
## collides with the world: it opens doors instead and walks through loot.
const LAYER_WORLD: int = 1
const LAYER_DOORS: int = 2
const LAYER_ITEMS: int = 4
