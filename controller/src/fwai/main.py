from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from .config import ControllerConfig
from .loop import ControllerLoop
from .policies.mvp_space_policy import MVPSpacePolicy
from .rcon_client import RCONClient


def main() -> int:
    config = ControllerConfig.from_args()
    client = RCONClient(
        host=config.rcon_host,
        port=config.rcon_port,
        password=config.rcon_password,
    )
    policy = MVPSpacePolicy()

    now = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    log_path = Path("logs") / f"controller-{now}.jsonl"

    loop = ControllerLoop(
        config=config,
        policy=policy,
        client=client,
        log_path=log_path,
    )

    try:
        loop.run()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
