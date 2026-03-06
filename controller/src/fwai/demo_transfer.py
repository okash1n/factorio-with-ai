from __future__ import annotations

import argparse
import json
import time
from typing import Any

from .bridge_commands import act, observe, reset_bot
from .constraints import validate_action
from .protocol import Action
from .rcon_client import RCONClient


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
    return sum(_inventory_count(snapshot, item_name) for snapshot in inventories.values())


def _distance(a: dict[str, Any], b: dict[str, Any]) -> float:
    ax = float(a["x"])
    ay = float(a["y"])
    bx = float(b["x"])
    by = float(b["y"])
    return ((ax - bx) ** 2 + (ay - by) ** 2) ** 0.5


def select_source_entity(observation: dict[str, Any], item_name: str) -> dict[str, Any] | None:
    bot = observation.get("bot")
    if not isinstance(bot, dict):
        return None
    bot_position = bot.get("position")
    if not isinstance(bot_position, dict):
        return None

    candidates: list[dict[str, Any]] = []
    for entity in observation.get("entities", []):
        if not isinstance(entity, dict):
            continue
        if not isinstance(entity.get("unit_number"), int):
            continue
        position = entity.get("position")
        if not isinstance(position, dict):
            continue
        item_count = _entity_inventory_count(entity, item_name)
        if item_count < 1:
            continue
        candidates.append(entity)

    if not candidates:
        return None

    candidates.sort(key=lambda entity: _distance(bot_position, entity["position"]))
    return candidates[0]


def select_sink_entity(observation: dict[str, Any], source_unit_number: int) -> dict[str, Any] | None:
    bot = observation.get("bot")
    if not isinstance(bot, dict):
        return None
    bot_position = bot.get("position")
    if not isinstance(bot_position, dict):
        return None
    bot_unit_number = bot.get("unit_number")

    preferred: list[dict[str, Any]] = []
    fallback: list[dict[str, Any]] = []
    for entity in observation.get("entities", []):
        if not isinstance(entity, dict):
            continue
        unit_number = entity.get("unit_number")
        if not isinstance(unit_number, int) or unit_number == source_unit_number or unit_number == bot_unit_number:
            continue
        if not isinstance(entity.get("inventories"), dict):
            continue
        position = entity.get("position")
        if not isinstance(position, dict):
            continue
        fallback.append(entity)
        if entity.get("force") == "player" and entity.get("type") == "container":
            preferred.append(entity)

    candidates = preferred or fallback
    if not candidates:
        return None
    candidates.sort(key=lambda entity: _distance(bot_position, entity["position"]))
    return candidates[0]


def wait_until_in_range(
    client: RCONClient,
    *,
    player_index: int,
    target_position: dict[str, float],
    distance_limit: float,
    timeout_seconds: float,
) -> dict[str, Any]:
    deadline = time.monotonic() + timeout_seconds
    latest = observe(client, player_index=player_index, radius=96.0, max_entities=256, ensure_bot=True)
    while time.monotonic() < deadline:
        bot = latest.get("bot")
        if isinstance(bot, dict) and isinstance(bot.get("position"), dict):
            if _distance(bot["position"], target_position) <= distance_limit:
                return latest
        time.sleep(0.25)
        latest = observe(client, player_index=player_index, radius=96.0, max_entities=256, ensure_bot=True)
    raise TimeoutError("bot did not reach target in time")


def run_demo(
    client: RCONClient,
    *,
    player_index: int,
    item_name: str,
    timeout_seconds: float,
) -> dict[str, Any]:
    summary: dict[str, Any] = {
        "item": item_name,
        "steps": [],
    }

    reset_response = reset_bot(client, player_index=player_index)
    summary["steps"].append({"step": "reset", "response": reset_response})

    observation = observe(client, player_index=player_index, radius=96.0, max_entities=256, ensure_bot=True)
    source = select_source_entity(observation, item_name)
    if source is None:
        raise RuntimeError(f"source entity with item not found: {item_name}")
    sink = select_sink_entity(observation, source["unit_number"])
    if sink is None:
        raise RuntimeError("sink entity not found")

    summary["source"] = source
    summary["sink"] = sink

    move_to_source = Action(type="move", params=source["position"])
    move_constraint = validate_action(move_to_source, observation)
    if not move_constraint.allowed:
        raise RuntimeError(f"move to source blocked: {move_constraint.reason}")
    move_response = act(client, player_index=player_index, action=move_to_source)
    summary["steps"].append(
        {
            "step": "move_to_source",
            "constraint": {"allowed": move_constraint.allowed, "reason": move_constraint.reason},
            "response": move_response,
        }
    )

    observation = wait_until_in_range(
        client,
        player_index=player_index,
        target_position=source["position"],
        distance_limit=5.0,
        timeout_seconds=timeout_seconds,
    )

    take_action = Action(
        type="take",
        params={
            "item": item_name,
            "count": 1,
            "target_unit_number": source["unit_number"],
        },
    )
    take_constraint = validate_action(take_action, observation)
    if not take_constraint.allowed:
        raise RuntimeError(f"take blocked: {take_constraint.reason}")
    take_response = act(client, player_index=player_index, action=take_action)
    summary["steps"].append(
        {
            "step": "take",
            "constraint": {"allowed": take_constraint.allowed, "reason": take_constraint.reason},
            "response": take_response,
        }
    )

    observation = observe(client, player_index=player_index, radius=96.0, max_entities=256, ensure_bot=True)
    move_to_sink = Action(type="move", params=sink["position"])
    sink_constraint = validate_action(move_to_sink, observation)
    if not sink_constraint.allowed:
        raise RuntimeError(f"move to sink blocked: {sink_constraint.reason}")
    sink_response = act(client, player_index=player_index, action=move_to_sink)
    summary["steps"].append(
        {
            "step": "move_to_sink",
            "constraint": {"allowed": sink_constraint.allowed, "reason": sink_constraint.reason},
            "response": sink_response,
        }
    )

    observation = wait_until_in_range(
        client,
        player_index=player_index,
        target_position=sink["position"],
        distance_limit=5.0,
        timeout_seconds=timeout_seconds,
    )

    insert_action = Action(
        type="insert",
        params={
            "item": item_name,
            "count": 1,
            "target_unit_number": sink["unit_number"],
        },
    )
    insert_constraint = validate_action(insert_action, observation)
    if not insert_constraint.allowed:
        raise RuntimeError(f"insert blocked: {insert_constraint.reason}")
    insert_response = act(client, player_index=player_index, action=insert_action)
    summary["steps"].append(
        {
            "step": "insert",
            "constraint": {"allowed": insert_constraint.allowed, "reason": insert_constraint.reason},
            "response": insert_response,
        }
    )

    summary["final_observation"] = observe(
        client,
        player_index=player_index,
        radius=96.0,
        max_entities=256,
        ensure_bot=True,
    )
    return summary


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run Day02 transfer demo")
    parser.add_argument("--rcon-host", default="127.0.0.1")
    parser.add_argument("--rcon-port", type=int, default=27015)
    parser.add_argument("--rcon-password", default="fwai-local")
    parser.add_argument("--player-index", type=int, default=1)
    parser.add_argument("--item", default="iron-plate")
    parser.add_argument("--timeout-seconds", type=float, default=20.0)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    client = RCONClient(
        host=args.rcon_host,
        port=args.rcon_port,
        password=args.rcon_password,
    )
    try:
        summary = run_demo(
            client,
            player_index=args.player_index,
            item_name=args.item,
            timeout_seconds=args.timeout_seconds,
        )
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
