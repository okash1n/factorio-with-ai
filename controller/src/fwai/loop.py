from __future__ import annotations

import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .bridge_commands import health, observe, act
from .config import ControllerConfig
from .constraints import validate_action
from .protocol import Action
from .rcon_client import RCONClient


@dataclass
class ControllerLoop:
    config: ControllerConfig
    policy: Any
    client: RCONClient
    log_path: Path

    def run(self) -> None:
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        health_response = health(self.client)
        self._log_event("health", {"response": health_response})

        step = 0
        while self.config.iterations == 0 or step < self.config.iterations:
            observation = observe(
                self.client,
                player_index=self.config.player_index,
                radius=48,
                max_entities=64,
                ensure_bot=True,
            )

            event: dict[str, Any] = {
                "step": step,
                "observation_ok": observation.get("ok", False),
                "observation_error": observation.get("error"),
            }

            if not observation.get("ok", False):
                event["action"] = {"type": "wait", "params": {}}
                event["constraint"] = {"allowed": False, "reason": "observation_not_ready"}
                event["act_response"] = {"ok": False, "reason": "observation_not_ready"}
            else:
                action: Action = self.policy.decide(observation)
                constraint = validate_action(action, observation)
                event["action"] = {"type": action.type, "params": action.params}
                event["constraint"] = {"allowed": constraint.allowed, "reason": constraint.reason}

                if constraint.allowed:
                    act_response = act(self.client, player_index=self.config.player_index, action=action)
                    event["act_response"] = act_response
                else:
                    event["act_response"] = {"ok": False, "reason": "blocked_by_constraints"}

            self._log_event("loop", event)
            step += 1
            time.sleep(self.config.loop_seconds)

    def _log_event(self, event_type: str, payload: dict[str, Any]) -> None:
        line = {"ts": time.time(), "event_type": event_type, "payload": payload}
        with self.log_path.open("a", encoding="utf-8") as fp:
            fp.write(json.dumps(line, ensure_ascii=False) + "\n")
