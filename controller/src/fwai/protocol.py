from __future__ import annotations

import base64
import json
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class Action:
    type: str
    params: dict[str, Any]


def encode_json_base64(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return base64.b64encode(raw).decode("ascii")


def decode_json_base64(payload: str) -> dict[str, Any]:
    raw = base64.b64decode(payload.encode("ascii"))
    decoded = json.loads(raw.decode("utf-8"))
    if not isinstance(decoded, dict):
        raise ValueError("decoded payload must be a JSON object")
    return decoded


def parse_rcon_json(line: str) -> dict[str, Any]:
    parsed = json.loads(line)
    if not isinstance(parsed, dict):
        raise ValueError("RCON line is not a JSON object")
    return parsed
