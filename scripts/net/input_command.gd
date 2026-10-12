class_name InputCommand
extends RefCounted

## Shared command shape for player touch/keyboard and bot AI.
## Online play will serialize these dictionaries over the wire.

const MOVE := "move"
const MOVE_TO := "move_to"
const ATTACK := "attack"
const ATTACK_TARGET := "attack_target"
const INTERACT := "interact"
const ABILITY := "ability"
const BUY := "buy"
const SHOP_TOGGLE := "shop_toggle"


static func move(unit_id: int, dir: Vector2) -> Dictionary:
	return {"type": MOVE, "unit_id": unit_id, "dir": {"x": dir.x, "y": dir.y}}


static func move_to(unit_id: int, pos: Vector2) -> Dictionary:
	return {"type": MOVE_TO, "unit_id": unit_id, "pos": {"x": pos.x, "y": pos.y}}


static func attack(unit_id: int) -> Dictionary:
	return {"type": ATTACK, "unit_id": unit_id}


static func attack_target(unit_id: int, target_id: int) -> Dictionary:
	return {"type": ATTACK_TARGET, "unit_id": unit_id, "target_id": target_id}


static func interact(unit_id: int, interact_id: String = "") -> Dictionary:
	return {"type": INTERACT, "unit_id": unit_id, "interact_id": interact_id}


static func ability(unit_id: int, slot: int) -> Dictionary:
	return {"type": ABILITY, "unit_id": unit_id, "slot": slot}


static func buy(unit_id: int, item_id: String) -> Dictionary:
	return {"type": BUY, "unit_id": unit_id, "item_id": item_id}


static func shop_toggle(unit_id: int) -> Dictionary:
	return {"type": SHOP_TOGGLE, "unit_id": unit_id}


static func dir_from(command: Dictionary) -> Vector2:
	var d: Dictionary = command.get("dir", {"x": 0.0, "y": 0.0})
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))


static func pos_from(command: Dictionary) -> Vector2:
	var p: Dictionary = command.get("pos", {"x": 0.0, "y": 0.0})
	return Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
