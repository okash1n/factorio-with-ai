# factorio-with-ai

Local automation scaffold for controlling Factorio (Space Age) via Codex + RCON.

## Scope
- Space Age enabled (`base`, `elevated-rails`, `quality`, `space-age`)
- Only one non-official mod: `fwai_bridge`
- Local headless server managed from this repository

## Prerequisites
- macOS + Steam Factorio installed
- Python 3.11+

Default Steam Factorio binary path:
`~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio`

## Quick Start
1. Start server:
```bash
./scripts/start_server.sh
```

2. In another terminal, run controller:
```bash
./scripts/run_controller.sh
```

3. Optional: connect local client:
```bash
./scripts/start_client_mac.sh
```

`start_client_mac.sh` automatically prepares a dedicated client runtime under `.runtime/client/` and installs `fwai_bridge` there, so mod-portal download is not required.

If you want to use the default user profile mods directory instead, run:

```bash
./scripts/install_client_mod.sh
```

`install_client_mod.sh` uses symlink mode by default:
- `~/Library/Application Support/Factorio/mods/fwai_bridge` points to `mod/fwai_bridge` in this repo.
- Mod edits in this repo are reflected in your local client mod directory immediately (restart client to reload mods).

For remote Windows client distribution:

```bash
./scripts/export_mod_bundle.sh
```

Copy the generated zip in `dist/` to `%APPDATA%\Factorio\mods\` on Windows.

## launchd (Background)
Install and run the server as a user LaunchAgent:

```bash
./scripts/launchd_server.sh start
```

Useful commands:

```bash
./scripts/launchd_server.sh status
./scripts/launchd_server.sh logs
./scripts/launchd_server.sh stop
./scripts/launchd_server.sh uninstall
```

## Local Board
Run the local Kanban UI:

```bash
./scripts/start_board.sh
```

Default URL:
`http://127.0.0.1:8127`

Notes:
- Board layout is stored in `board/board.json`
- Task cards are stored in `board/cards/00001.md` style Markdown files
- The browser UI supports drag-and-drop between columns
- Card edits are saved back to the repository JSON via the local Python server
- Card ID is numeric in the UI, and semantic keys are stored inside each card Markdown file
- `key:` may be blank when you add a card; the server fills it on save without renaming the file

Run the board via launchd:

```bash
./scripts/launchd_board.sh start
```

Useful commands:

```bash
./scripts/launchd_board.sh status
./scripts/launchd_board.sh logs
./scripts/launchd_board.sh stop
./scripts/launchd_board.sh uninstall
```

## Environment Variables
- `FACTORIO_BIN`: override Factorio binary path
- `RCON_PORT`: default `27015`
- `RCON_PASSWORD`: default `fwai-local`
- `GAME_PORT`: default `34197`
- `LOOP_SECONDS`: controller loop sleep interval (default `1.0`)
- `ITERATIONS`: loop count (default `0` means infinite)

## Notes
- Server runtime files are isolated under `.runtime/server/`.
- Client runtime files are isolated under `.runtime/client/`.
- `scripts/verify_modset.sh` validates enabled mod set.
- LaunchAgent label default: `com.okash1n.fwai.server`.
