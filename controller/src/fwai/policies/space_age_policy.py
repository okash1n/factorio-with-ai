from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from ..protocol import Action


@dataclass
class SpaceAgePolicy:
    """Placeholder for the full Space Age strategy."""

    def decide(self, _observation: dict[str, Any]) -> Action:
        return Action(type="wait", params={})
