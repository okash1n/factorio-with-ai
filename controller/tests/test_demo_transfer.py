from __future__ import annotations

import unittest

from fwai.demo_transfer import select_sink_entity, select_source_entity


class DemoTransferTests(unittest.TestCase):
    def test_select_source_entity_prefers_nearest_with_item(self) -> None:
        observation = {
            "bot": {"position": {"x": 0.0, "y": 0.0}},
            "entities": [
                {
                    "unit_number": 10,
                    "position": {"x": 10.0, "y": 0.0},
                    "inventories": {"main": [{"name": "iron-plate", "count": 1}]},
                },
                {
                    "unit_number": 11,
                    "position": {"x": 3.0, "y": 0.0},
                    "inventories": {"main": [{"name": "iron-plate", "count": 2}]},
                },
            ],
        }

        selected = select_source_entity(observation, "iron-plate")

        self.assertIsNotNone(selected)
        self.assertEqual(selected["unit_number"], 11)

    def test_select_sink_entity_prefers_player_force_container(self) -> None:
        observation = {
            "bot": {"unit_number": 7, "position": {"x": 0.0, "y": 0.0}},
            "entities": [
                {
                    "unit_number": 7,
                    "force": "player",
                    "position": {"x": 2.0, "y": 0.0},
                    "type": "spider-vehicle",
                    "inventories": {"main": []},
                },
                {
                    "unit_number": 11,
                    "force": "player",
                    "position": {"x": 5.0, "y": 0.0},
                    "type": "container",
                    "inventories": {"main": []},
                },
            ],
        }

        selected = select_sink_entity(observation, 99)

        self.assertIsNotNone(selected)
        self.assertEqual(selected["unit_number"], 11)


if __name__ == "__main__":
    unittest.main()
