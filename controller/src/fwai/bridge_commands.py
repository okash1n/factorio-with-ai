from __future__ import annotations

import uuid
from typing import Any

from .protocol import Action, encode_json_base64, parse_rcon_json
from .rcon_client import RCONClient


def command_json(client: RCONClient, command_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    encoded = encode_json_base64(payload)
    raw = client.command(f"/{command_name} {encoded}")
    return parse_rcon_json(raw)


def health(client: RCONClient) -> dict[str, Any]:
    return command_json(client, "fwai.health", {})


def observe(
    client: RCONClient,
    *,
    player_index: int,
    radius: float = 48.0,
    max_entities: int = 64,
    ensure_bot: bool = True,
) -> dict[str, Any]:
    payload = {
        "v": 1,
        "request_id": str(uuid.uuid4()),
        "player_index": player_index,
        "radius": radius,
        "max_entities": max_entities,
        "ensure_bot": ensure_bot,
    }
    return command_json(client, "fwai.observe", payload)


def reset_bot(client: RCONClient, *, player_index: int) -> dict[str, Any]:
    payload = {
        "v": 1,
        "request_id": str(uuid.uuid4()),
        "player_index": player_index,
    }
    return command_json(client, "fwai.reset", payload)


def read_bot_state(client: RCONClient, *, player_index: int) -> dict[str, Any]:
    payload = {
        "v": 1,
        "request_id": str(uuid.uuid4()),
        "player_index": player_index,
    }
    return command_json(client, "fwai.bot_state", payload)


def act(client: RCONClient, *, player_index: int, action: Action) -> dict[str, Any]:
    payload = {
        "v": 1,
        "request_id": str(uuid.uuid4()),
        "player_index": player_index,
        "action": {"type": action.type, "params": action.params},
    }
    return command_json(client, "fwai.act", payload)
