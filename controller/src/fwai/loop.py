from __future__ import annotations

import json
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import ControllerConfig
from .constraints import validate_action
from .protocol import Action, encode_json_base64, parse_rcon_json
from .rcon_client import RCONClient


@dataclass
class ControllerLoop:
    config: ControllerConfig
    policy: Any
    client: RCONClient
    log_path: Path

    def run(self) -> None:
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        health = self._command_json("fwai.health", {})
        self._log_event("health", {"response": health})

        step = 0
        while self.config.iterations == 0 or step < self.config.iterations:
            observe_request = {
                "v": 1,
                "request_id": str(uuid.uuid4()),
                "player_index": self.config.player_index,
                "radius": 48,
            }
            observation = self._command_json("fwai.observe", observe_request)

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
                    act_request = {
                        "v": 1,
                        "request_id": str(uuid.uuid4()),
                        "player_index": self.config.player_index,
                        "action": {"type": action.type, "params": action.params},
                    }
                    act_response = self._command_json("fwai.act", act_request)
                    event["act_response"] = act_response
                else:
                    event["act_response"] = {"ok": False, "reason": "blocked_by_constraints"}

            self._log_event("loop", event)
            step += 1
            time.sleep(self.config.loop_seconds)

    def _command_json(self, command_name: str, payload: dict[str, Any]) -> dict[str, Any]:
        encoded = encode_json_base64(payload)
        raw = self.client.command(f"/{command_name} {encoded}")
        return parse_rcon_json(raw)

    def _log_event(self, event_type: str, payload: dict[str, Any]) -> None:
        line = {"ts": time.time(), "event_type": event_type, "payload": payload}
        with self.log_path.open("a", encoding="utf-8") as fp:
            fp.write(json.dumps(line, ensure_ascii=False) + "\n")
