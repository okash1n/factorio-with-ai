from __future__ import annotations

import argparse
import json
from typing import Any

from .bridge_commands import act, health, observe, read_bot_state, reset_bot
from .constraints import validate_action
from .protocol import Action
from .rcon_client import RCONClient


def _bool_arg(value: str) -> bool:
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise argparse.ArgumentTypeError(f"invalid boolean value: {value}")


def _json_object(value: str) -> dict[str, Any]:
    parsed = json.loads(value)
    if not isinstance(parsed, dict):
        raise argparse.ArgumentTypeError("params must be a JSON object")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="FWAI one-shot controller")
    parser.add_argument("--rcon-host", default="127.0.0.1")
    parser.add_argument("--rcon-port", type=int, default=27015)
    parser.add_argument("--rcon-password", default="fwai-local")
    parser.add_argument("--player-index", type=int, default=1)

    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("health", help="Read bridge health")

    observe_parser = subparsers.add_parser("observe", help="Read observation snapshot")
    observe_parser.add_argument("--radius", type=float, default=48.0)
    observe_parser.add_argument("--max-entities", type=int, default=64)
    observe_parser.add_argument("--ensure-bot", type=_bool_arg, default=True)

    subparsers.add_parser("reset", help="Destroy and respawn bot")
    subparsers.add_parser("bot-state", help="Read bot state only")

    act_parser = subparsers.add_parser("act", help="Run one action")
    act_parser.add_argument("--type", required=True, dest="action_type")
    act_parser.add_argument("--params", default="{}", type=_json_object)
    act_parser.add_argument("--skip-constraints", action="store_true")
    act_parser.add_argument("--radius", type=float, default=96.0)
    act_parser.add_argument("--max-entities", type=int, default=256)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    client = RCONClient(
        host=args.rcon_host,
        port=args.rcon_port,
        password=args.rcon_password,
    )

    try:
        if args.command == "health":
            print(json.dumps(health(client), ensure_ascii=False, indent=2))
            return 0

        if args.command == "observe":
            response = observe(
                client,
                player_index=args.player_index,
                radius=args.radius,
                max_entities=args.max_entities,
                ensure_bot=args.ensure_bot,
            )
            print(json.dumps(response, ensure_ascii=False, indent=2))
            return 0

        if args.command == "reset":
            print(json.dumps(reset_bot(client, player_index=args.player_index), ensure_ascii=False, indent=2))
            return 0

        if args.command == "bot-state":
            print(json.dumps(read_bot_state(client, player_index=args.player_index), ensure_ascii=False, indent=2))
            return 0

        if args.command == "act":
            action = Action(type=args.action_type, params=args.params)
            observation = observe(
                client,
                player_index=args.player_index,
                radius=args.radius,
                max_entities=args.max_entities,
                ensure_bot=True,
            )
            output: dict[str, Any] = {
                "observation_ok": observation.get("ok", False),
                "action": {"type": action.type, "params": action.params},
            }
            if not observation.get("ok", False):
                output["constraint"] = {"allowed": False, "reason": "observation_not_ready"}
                output["response"] = {"ok": False, "reason": "observation_not_ready"}
                print(json.dumps(output, ensure_ascii=False, indent=2))
                return 1

            if args.skip_constraints:
                output["constraint"] = {"allowed": True, "reason": "skipped"}
                response = act(client, player_index=args.player_index, action=action)
                output["response"] = response
                print(json.dumps(output, ensure_ascii=False, indent=2))
                return 0 if response.get("ok", False) else 1

            constraint = validate_action(action, observation)
            output["constraint"] = {"allowed": constraint.allowed, "reason": constraint.reason}
            if not constraint.allowed:
                output["response"] = {"ok": False, "reason": "blocked_by_constraints"}
                print(json.dumps(output, ensure_ascii=False, indent=2))
                return 1

            response = act(client, player_index=args.player_index, action=action)
            output["response"] = response
            print(json.dumps(output, ensure_ascii=False, indent=2))
            return 0 if response.get("ok", False) else 1

        raise AssertionError("unreachable")
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
