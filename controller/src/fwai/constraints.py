from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from .protocol import Action


@dataclass(frozen=True)
class ConstraintResult:
    allowed: bool
    reason: str


def validate_action(
    action: Action,
    observation: dict[str, Any],
    max_move_distance: float = 64.0,
    max_interaction_distance: float = 6.0,
) -> ConstraintResult:
    if action.type == "wait":
        return ConstraintResult(True, "wait_is_always_allowed")

    if not _observer_is_connected(observation):
        return ConstraintResult(False, "observer_not_connected")

    if action.type == "spawn_bot":
        return ConstraintResult(True, "spawn_bot_allowed")

    bot = observation.get("bot")
    if not isinstance(bot, dict):
        return ConstraintResult(False, "bot_not_visible")
    position = bot.get("position")
    if not isinstance(position, dict):
        return ConstraintResult(False, "bot_position_missing")

    if action.type == "move":
        target_x = _get_number(action.params.get("x"))
        target_y = _get_number(action.params.get("y"))
        if target_x is None or target_y is None:
            return ConstraintResult(False, "invalid_target")
        distance = _distance(position, {"x": target_x, "y": target_y})
        if distance > max_move_distance:
            return ConstraintResult(False, "move_too_far")
        return ConstraintResult(True, "move_allowed")

    if action.type == "place":
        item_name = _get_item_name(action)
        if item_name is None:
            return ConstraintResult(False, "item_name_missing")
        target = _get_target_position(action.params)
        if target is None:
            return ConstraintResult(False, "invalid_target")
        if _distance(position, target) > max_interaction_distance:
            return ConstraintResult(False, "interaction_too_far")
        if _inventory_count(bot.get("inventory"), item_name) < 1:
            return ConstraintResult(False, "bot_inventory_missing_item")
        if _position_occupied(observation.get("entities"), target):
            return ConstraintResult(False, "target_position_occupied")
        return ConstraintResult(True, "place_allowed")

    if action.type == "insert":
        item_name = _get_item_name(action)
        if item_name is None:
            return ConstraintResult(False, "item_name_missing")
        target = _find_target_entity(observation, action.params.get("target_unit_number"))
        if target is None:
            return ConstraintResult(False, "target_entity_not_found")
        if _distance(position, target.get("position")) > max_interaction_distance:
            return ConstraintResult(False, "interaction_too_far")
        count = _get_positive_int(action.params.get("count"), default=1)
        if count is None:
            return ConstraintResult(False, "invalid_count")
        if _inventory_count(bot.get("inventory"), item_name) < count:
            return ConstraintResult(False, "bot_inventory_missing_item")
        return ConstraintResult(True, "insert_allowed")

    if action.type == "take":
        item_name = _get_item_name(action)
        if item_name is None:
            return ConstraintResult(False, "item_name_missing")
        target = _find_target_entity(observation, action.params.get("target_unit_number"))
        if target is None:
            return ConstraintResult(False, "target_entity_not_found")
        if _distance(position, target.get("position")) > max_interaction_distance:
            return ConstraintResult(False, "interaction_too_far")
        count = _get_positive_int(action.params.get("count"), default=1)
        if count is None:
            return ConstraintResult(False, "invalid_count")
        if _entity_inventory_count(target, item_name) < count:
            return ConstraintResult(False, "target_inventory_missing_item")
        return ConstraintResult(True, "take_allowed")

    return ConstraintResult(False, f"unsupported_action:{action.type}")


def _get_number(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _get_positive_int(value: Any, default: int) -> int | None:
    if value is None:
        return default
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if value > 0 else None
    if isinstance(value, float) and value.is_integer() and value > 0:
        return int(value)
    return None


def _get_item_name(action: Action) -> str | None:
    value = action.params.get("item") or action.params.get("item_name")
    return value if isinstance(value, str) and value else None


def _get_target_position(params: dict[str, Any]) -> dict[str, float] | None:
    target_x = _get_number(params.get("x"))
    target_y = _get_number(params.get("y"))
    if target_x is None or target_y is None:
        return None
    return {"x": target_x, "y": target_y}


def _distance(origin: Any, target: Any) -> float:
    origin_x = _get_number(origin.get("x")) if isinstance(origin, dict) else None
    origin_y = _get_number(origin.get("y")) if isinstance(origin, dict) else None
    target_x = _get_number(target.get("x")) if isinstance(target, dict) else None
    target_y = _get_number(target.get("y")) if isinstance(target, dict) else None
    if None in (origin_x, origin_y, target_x, target_y):
        return math.inf
    return math.dist([origin_x, origin_y], [target_x, target_y])


def _inventory_count(snapshot: Any, item_name: str) -> int:
    if not isinstance(snapshot, list):
        return 0
    total = 0
    for entry in snapshot:
        if not isinstance(entry, dict):
            continue
        if entry.get("name") != item_name:
            continue
        count = entry.get("count")
        if isinstance(count, int):
            total += count
    return total


def _entity_inventory_count(entity: dict[str, Any], item_name: str) -> int:
    inventories = entity.get("inventories")
    if not isinstance(inventories, dict):
        return 0
    total = 0
    for snapshot in inventories.values():
        total += _inventory_count(snapshot, item_name)
    return total


def _find_target_entity(observation: dict[str, Any], unit_number: Any) -> dict[str, Any] | None:
    if not isinstance(unit_number, int):
        return None
    entities = observation.get("entities")
    if not isinstance(entities, list):
        return None
    for entity in entities:
        if not isinstance(entity, dict):
            continue
        if entity.get("unit_number") == unit_number:
            return entity
    return None


def _position_occupied(entities: Any, target: dict[str, float], tolerance: float = 0.25) -> bool:
    if not isinstance(entities, list):
        return False
    for entity in entities:
        if not isinstance(entity, dict):
            continue
        position = entity.get("position")
        if _distance(position, target) <= tolerance:
            return True
    return False


def _observer_is_connected(observation: dict[str, Any]) -> bool:
    player = observation.get("player")
    if not isinstance(player, dict):
        return True
    connected = player.get("connected")
    if connected is False:
        return False
    return True
