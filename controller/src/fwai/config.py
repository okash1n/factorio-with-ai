from __future__ import annotations

import argparse
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class ControllerConfig:
    rcon_host: str
    rcon_port: int
    rcon_password: str
    loop_seconds: float
    iterations: int
    player_index: int

    @classmethod
    def from_args(cls, argv: list[str] | None = None) -> "ControllerConfig":
        parser = argparse.ArgumentParser(description="FWAI controller")
        parser.add_argument("--rcon-host", default=os.getenv("RCON_HOST", "127.0.0.1"))
        parser.add_argument("--rcon-port", type=int, default=int(os.getenv("RCON_PORT", "27015")))
        parser.add_argument("--rcon-password", default=os.getenv("RCON_PASSWORD", "fwai-local"))
        parser.add_argument("--loop-seconds", type=float, default=float(os.getenv("LOOP_SECONDS", "1.0")))
        parser.add_argument("--iterations", type=int, default=int(os.getenv("ITERATIONS", "0")))
        parser.add_argument("--player-index", type=int, default=int(os.getenv("PLAYER_INDEX", "1")))
        args = parser.parse_args(argv)

        return cls(
            rcon_host=args.rcon_host,
            rcon_port=args.rcon_port,
            rcon_password=args.rcon_password,
            loop_seconds=args.loop_seconds,
            iterations=args.iterations,
            player_index=args.player_index,
        )
