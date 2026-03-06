from __future__ import annotations

import unittest

from fwai.protocol import decode_json_base64, encode_json_base64, parse_rcon_json


class ProtocolTests(unittest.TestCase):
    def test_base64_roundtrip(self) -> None:
        payload = {"v": 1, "request_id": "abc", "nested": {"x": 1, "y": 2}}
        encoded = encode_json_base64(payload)
        decoded = decode_json_base64(encoded)
        self.assertEqual(decoded, payload)

    def test_parse_rcon_json(self) -> None:
        parsed = parse_rcon_json('{"ok":true,"tick":123}')
        self.assertEqual(parsed["ok"], True)
        self.assertEqual(parsed["tick"], 123)


if __name__ == "__main__":
    unittest.main()
