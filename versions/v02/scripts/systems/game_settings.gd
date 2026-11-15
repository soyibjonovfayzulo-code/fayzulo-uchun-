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
