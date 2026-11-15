extends Node
## Sandbox settings (Project Zomboid style). Change here to tune a playthrough.

## Chance that a bite which breaks the skin carries the infection.
@export_range(0.0, 1.0) var infection_chance_bite := 0.35
## Scratches/lacerations can also infect (much rarer).
@export_range(0.0, 1.0) var infection_chance_scratch := 0.05
@export_range(0.0, 1.0) var infection_chance_laceration := 0.12
## Game hours from infection to death.
@export var infection_hours_to_death := 72.0
@export var zombie_count := 60
@export_range(0.5, 2.0) var zombie_speed := 1.0
@export_range(0.5, 2.0) var zombie_damage := 1.0
@export_range(0.5, 2.0) var loot_rarity := 1.0
## Brick shed next to the spawn with crates holding every item (for testing and filming).
@export var test_room := true
## Day on which power, gas and tap water die (0 = never).
@export var utilities_off_day := 3
## Rain spells (deterministic schedule from world_seed).
@export var weather := true
@export var world_seed := 1993
## Real minutes per game day.
@export var day_length_minutes := 48.0
@export_range(0.0, 23.0) var start_hour := 8.5
## Seconds between death by infection and getting up as a zombie.
@export var reanimate_seconds := 4.0
## Set by the new-game menu: load user://saves/<slot>.json when the world starts.
var load_save := false
