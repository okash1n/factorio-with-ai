from __future__ import annotations

import argparse
import json
import re
import unicodedata
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


ROOT_DIR = Path(__file__).resolve().parent
WEB_DIR = ROOT_DIR / "web"
BOARD_FILE = ROOT_DIR / "board.json"
CARDS_DIR = ROOT_DIR / "cards"
LIST_FIELDS = {"tags", "links"}


def load_board() -> dict:
    board_index = load_board_index()
    cards = load_cards(board_index["columns"])
    return build_board_payload(
        title=board_index["title"],
        updated_at=board_index.get("updated_at"),
        columns=board_index["columns"],
        cards=cards,
    )


def save_board(payload: dict) -> dict:
    normalized = normalize_board_payload(payload)
    normalized["updated_at"] = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    write_board_index(normalized)
    write_card_files(normalized["cards"])
    prune_card_files(normalized["cards"])
    return build_board_payload(
        title=normalized["title"],
        updated_at=normalized["updated_at"],
        columns=normalized["columns"],
        cards=normalized["cards"],
    )


def load_board_index() -> dict:
    with BOARD_FILE.open("r", encoding="utf-8") as fp:
        payload = json.load(fp)
    if not isinstance(payload, dict):
        raise ValueError("board.json must contain an object")
    columns = payload.get("columns")
    if not isinstance(columns, list):
        raise ValueError("'columns' must be a list")
    normalized_columns: list[dict] = []
    for column in columns:
        if not isinstance(column, dict):
            raise ValueError("each column must be an object")
        column_id = require_non_empty_string(column.get("id"), "column id")
        column_title = require_non_empty_string(column.get("title"), f"column {column_id} title")
        normalized_columns.append({"id": column_id, "title": column_title})
    return {
        "title": require_non_empty_string(payload.get("title"), "board title"),
        "updated_at": payload.get("updated_at"),
        "columns": normalized_columns,
    }


def load_cards(columns: list[dict]) -> list[dict]:
    ensure_cards_dir()
    known_columns = {column["id"] for column in columns}
    seen_ids: set[int] = set()
    seen_keys: set[str] = set()
    cards: list[dict] = []
    for path in sorted(CARDS_DIR.glob("*.md")):
        card = parse_card_file(path)
        if card["column"] not in known_columns:
            raise ValueError(f"unknown column '{card['column']}' in {path.name}")
        if card["id"] in seen_ids:
            raise ValueError(f"duplicate card id: {card['id']}")
        seen_ids.add(card["id"])
        if card["key"]:
            if card["key"] in seen_keys:
                raise ValueError(f"duplicate card key: {card['key']}")
            seen_keys.add(card["key"])
        cards.append(card)
    return sort_cards(cards, columns)


def parse_card_file(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    metadata, body = parse_markdown_document(text, path)
    card_id = parse_int(metadata.get("id"), f"{path.name} id")
    if path.stem.isdigit() and int(path.stem) != card_id:
        raise ValueError(f"{path.name} id does not match filename")
    title = require_non_empty_string(metadata.get("title"), f"{path.name} title")
    column = require_non_empty_string(metadata.get("column"), f"{path.name} column")
    raw_key = metadata.get("key", "")
    key = raw_key.strip() if isinstance(raw_key, str) else ""
    raw_position = metadata.get("position")
    position = card_id if raw_position in (None, "") else parse_int(raw_position, f"{path.name} position")
    return {
        "id": card_id,
        "key": key,
        "title": title,
        "description": body.strip(),
        "tags": normalize_string_list(metadata.get("tags", [])),
        "links": normalize_string_list(metadata.get("links", [])),
        "column": column,
        "position": position,
    }


def parse_markdown_document(text: str, path: Path) -> tuple[dict, str]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ValueError(f"{path.name} must start with front matter")
    meta_lines: list[str] = []
    line_index = 1
    while line_index < len(lines) and lines[line_index] != "---":
        meta_lines.append(lines[line_index])
        line_index += 1
    if line_index >= len(lines):
        raise ValueError(f"{path.name} front matter is not closed")
    metadata = parse_front_matter(meta_lines, path)
    body = "\n".join(lines[line_index + 1 :]).strip()
    return metadata, body


def parse_front_matter(lines: list[str], path: Path) -> dict:
    metadata: dict[str, object] = {}
    current_list_key: str | None = None
    for raw_line in lines:
        stripped = raw_line.strip()
        if not stripped:
            continue
        if current_list_key and stripped.startswith("- "):
            values = metadata.setdefault(current_list_key, [])
            if not isinstance(values, list):
                raise ValueError(f"{path.name} has invalid list field '{current_list_key}'")
            values.append(stripped[2:].strip())
            continue
        key, separator, value = raw_line.partition(":")
        if separator != ":":
            raise ValueError(f"{path.name} has invalid metadata line: {raw_line}")
        normalized_key = key.strip()
        normalized_value = value.lstrip()
        if normalized_key in LIST_FIELDS:
            values = metadata.setdefault(normalized_key, [])
            if not isinstance(values, list):
                raise ValueError(f"{path.name} has invalid list field '{normalized_key}'")
            if normalized_value:
                values.append(normalized_value)
            current_list_key = normalized_key
            continue
        metadata[normalized_key] = normalized_value
        current_list_key = None
    return metadata


def normalize_board_payload(payload: dict) -> dict:
    if not isinstance(payload, dict):
        raise ValueError("request payload must be an object")
    columns = payload.get("columns")
    if not isinstance(columns, list):
        raise ValueError("'columns' must be a list")
    title = require_non_empty_string(payload.get("title"), "board title")

    normalized_columns: list[dict] = []
    normalized_cards: list[dict] = []
    seen_ids: set[int] = set()
    for column in columns:
        if not isinstance(column, dict):
            raise ValueError("each column must be an object")
        column_id = require_non_empty_string(column.get("id"), "column id")
        column_title = require_non_empty_string(column.get("title"), f"column {column_id} title")
        raw_cards = column.get("cards")
        if not isinstance(raw_cards, list):
            raise ValueError(f"column '{column_id}' cards must be a list")
        normalized_columns.append({"id": column_id, "title": column_title})
        for position, card in enumerate(raw_cards):
            normalized_card = normalize_card_payload(card, column_id, position)
            if normalized_card["id"] in seen_ids:
                raise ValueError(f"duplicate card id: {normalized_card['id']}")
            seen_ids.add(normalized_card["id"])
            normalized_cards.append(normalized_card)

    assign_semantic_keys(normalized_cards, normalized_columns)
    return {
        "title": title,
        "updated_at": payload.get("updated_at"),
        "columns": normalized_columns,
        "cards": sort_cards(normalized_cards, normalized_columns),
    }


def normalize_card_payload(card: dict, column_id: str, position: int) -> dict:
    if not isinstance(card, dict):
        raise ValueError("each card must be an object")
    card_id = card.get("id")
    if not isinstance(card_id, int) or isinstance(card_id, bool):
        raise ValueError("card requires integer 'id'")
    title = require_non_empty_string(card.get("title"), f"card {card_id} title")
    raw_key = card.get("key", "")
    key = raw_key.strip() if isinstance(raw_key, str) else ""
    description = card.get("description", "")
    if description is None:
        description = ""
    if not isinstance(description, str):
        raise ValueError(f"card {card_id} description must be a string")
    return {
        "id": card_id,
        "key": key,
        "title": title,
        "description": description.strip(),
        "tags": normalize_string_list(card.get("tags", [])),
        "links": normalize_string_list(card.get("links", [])),
        "column": column_id,
        "position": position,
    }


def assign_semantic_keys(cards: list[dict], columns: list[dict]) -> None:
    used_keys: set[str] = set()
    for card in sort_cards(cards, columns):
        preferred_key = normalize_key(card.get("key", ""))
        if preferred_key:
            candidate = preferred_key
        else:
            candidate = normalize_key(card["title"]) or f"card-{card['id']:05d}"
        suffix = 2
        unique_candidate = candidate
        while unique_candidate in used_keys:
            unique_candidate = f"{candidate}-{suffix}"
            suffix += 1
        card["key"] = unique_candidate
        used_keys.add(unique_candidate)


def sort_cards(cards: list[dict], columns: list[dict]) -> list[dict]:
    order_by_column = {column["id"]: index for index, column in enumerate(columns)}
    return sorted(
        cards,
        key=lambda card: (
            order_by_column.get(card["column"], len(order_by_column)),
            card["position"],
            card["id"],
        ),
    )


def normalize_key(value: object) -> str:
    if not isinstance(value, str):
        return ""
    normalized = unicodedata.normalize("NFKC", value).strip().lower()
    normalized = normalized.replace("『", " ").replace("』", " ")
    normalized = normalized.replace("「", " ").replace("」", " ")
    normalized = re.sub(r"[^\w]+", "-", normalized, flags=re.UNICODE)
    normalized = re.sub(r"-{2,}", "-", normalized).strip("-_")
    return normalized


def normalize_string_list(value: object) -> list[str]:
    if value in (None, ""):
        return []
    if isinstance(value, str):
        values = [value]
    elif isinstance(value, list):
        values = value
    else:
        raise ValueError("list field must be a list or string")
    result: list[str] = []
    for item in values:
        if not isinstance(item, str):
            raise ValueError("list field items must be strings")
        normalized = item.strip()
        if normalized:
            result.append(normalized)
    return result


def build_board_payload(title: str, updated_at: str | None, columns: list[dict], cards: list[dict]) -> dict:
    cards_by_column = {column["id"]: [] for column in columns}
    for card in sort_cards(cards, columns):
        cards_by_column.setdefault(card["column"], []).append(
            {
                "id": card["id"],
                "key": card["key"],
                "title": card["title"],
                "description": card["description"],
                "tags": list(card["tags"]),
                "links": list(card["links"]),
            }
        )
    return {
        "title": title,
        "updated_at": updated_at,
        "columns": [
            {
                "id": column["id"],
                "title": column["title"],
                "cards": cards_by_column.get(column["id"], []),
            }
            for column in columns
        ],
    }


def write_board_index(payload: dict) -> None:
    board_index = {
        "title": payload["title"],
        "updated_at": payload["updated_at"],
        "columns": payload["columns"],
    }
    temp_path = BOARD_FILE.with_suffix(".json.tmp")
    with temp_path.open("w", encoding="utf-8") as fp:
        json.dump(board_index, fp, ensure_ascii=False, indent=2)
        fp.write("\n")
    temp_path.replace(BOARD_FILE)


def write_card_files(cards: list[dict]) -> None:
    ensure_cards_dir()
    for card in sorted(cards, key=lambda candidate: candidate["id"]):
        card_path(card["id"]).write_text(render_card_markdown(card), encoding="utf-8")


def prune_card_files(cards: list[dict]) -> None:
    ensure_cards_dir()
    keep_paths = {card_path(card["id"]) for card in cards}
    for path in CARDS_DIR.glob("*.md"):
        if path not in keep_paths:
            path.unlink()


def render_card_markdown(card: dict) -> str:
    lines = [
        "---",
        f"id: {card['id']}",
        f"key: {card['key']}",
        f"column: {card['column']}",
        f"position: {card['position']}",
        f"title: {card['title']}",
        "tags:",
    ]
    for tag in card["tags"]:
        lines.append(f"  - {tag}")
    lines.append("links:")
    for link in card["links"]:
        lines.append(f"  - {link}")
    lines.append("---")
    lines.append("")
    description = card["description"].strip()
    if description:
        lines.append(description)
        lines.append("")
    return "\n".join(lines)


def card_path(card_id: int) -> Path:
    return CARDS_DIR / f"{card_id:05d}.md"


def ensure_cards_dir() -> None:
    CARDS_DIR.mkdir(parents=True, exist_ok=True)


def parse_int(value: object, label: str) -> int:
    if isinstance(value, bool):
        raise ValueError(f"{label} must be an integer")
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.strip():
        return int(value.strip())
    raise ValueError(f"{label} must be an integer")


def require_non_empty_string(value: object, label: str) -> str:
    if not isinstance(value, str):
        raise ValueError(f"{label} must be a string")
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{label} must not be empty")
    return normalized


class BoardHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_DIR), **kwargs)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/board":
            self._send_json(load_board())
            return
        if parsed.path == "/api/health":
            self._send_json({"ok": True})
            return
        super().do_GET()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/api/board":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode("utf-8"))
            saved = save_board(payload)
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError) as exc:
            self._send_json({"ok": False, "error": str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return

        self._send_json(saved)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        super().log_message(fmt, *args)

    def _send_json(self, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve the local Factorio with AI board.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8127)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    server = ThreadingHTTPServer((args.host, args.port), BoardHandler)
    print(f"board server listening on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nboard server stopped")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
