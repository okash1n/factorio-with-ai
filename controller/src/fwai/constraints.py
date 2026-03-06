from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from .protocol import Action


@dataclass(frozen=True)
class ConstraintResult:
    allowed: bool
    reason: str


def validate_action(action: Action, observation: dict[str, Any], max_move_distance: float = 64.0) -> ConstraintResult:
    if action.type == "wait":
        return ConstraintResult(True, "wait_is_always_allowed")

    if action.type == "spawn_bot":
        return ConstraintResult(True, "spawn_bot_allowed")

    if action.type == "move":
        bot = observation.get("bot")
        if not isinstance(bot, dict):
            return ConstraintResult(False, "bot_not_visible")
        position = bot.get("position")
        if not isinstance(position, dict):
            return ConstraintResult(False, "bot_position_missing")
        target_x = _get_number(action.params.get("x"))
        target_y = _get_number(action.params.get("y"))
        if target_x is None or target_y is None:
            return ConstraintResult(False, "invalid_target")
        distance = math.dist([position.get("x", 0.0), position.get("y", 0.0)], [target_x, target_y])
        if distance > max_move_distance:
            return ConstraintResult(False, "move_too_far")
        return ConstraintResult(True, "move_allowed")

    return ConstraintResult(False, f"unsupported_action:{action.type}")


def _get_number(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    return None
