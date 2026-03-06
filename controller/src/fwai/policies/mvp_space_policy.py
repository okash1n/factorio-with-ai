from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from ..protocol import Action


@dataclass
class MVPSpacePolicy:
    """Minimal policy scaffold for Phase 0/1.

    This policy is intentionally conservative:
    - Spawn bot if missing
    - Otherwise wait
    """

    def decide(self, observation: dict[str, Any]) -> Action:
        bot = observation.get("bot")
        if not isinstance(bot, dict):
            return Action(type="spawn_bot", params={})
        return Action(type="wait", params={})
