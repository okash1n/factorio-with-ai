from __future__ import annotations

import unittest

from fwai.constraints import validate_action
from fwai.protocol import Action


class ConstraintTests(unittest.TestCase):
    def test_wait_is_allowed(self) -> None:
        result = validate_action(Action(type="wait", params={}), observation={})
        self.assertTrue(result.allowed)

    def test_move_requires_bot(self) -> None:
        result = validate_action(Action(type="move", params={"x": 10.0, "y": 10.0}), observation={})
        self.assertFalse(result.allowed)

    def test_actions_require_connected_observer(self) -> None:
        obs = {
            "player": {"connected": False},
            "bot": {"position": {"x": 0.0, "y": 0.0}},
        }
        result = validate_action(Action(type="move", params={"x": 1.0, "y": 0.0}), observation=obs)
        self.assertFalse(result.allowed)
        self.assertEqual(result.reason, "observer_not_connected")

    def test_move_too_far_is_rejected(self) -> None:
        obs = {"bot": {"position": {"x": 0.0, "y": 0.0}}}
        result = validate_action(Action(type="move", params={"x": 1000.0, "y": 0.0}), observation=obs)
        self.assertFalse(result.allowed)

    def test_move_in_range_is_allowed(self) -> None:
        obs = {"bot": {"position": {"x": 0.0, "y": 0.0}}}
        result = validate_action(Action(type="move", params={"x": 10.0, "y": 0.0}), observation=obs)
        self.assertTrue(result.allowed)

    def test_place_requires_bot_inventory_item(self) -> None:
        obs = {"bot": {"position": {"x": 0.0, "y": 0.0}, "inventory": []}, "entities": []}
        result = validate_action(
            Action(type="place", params={"item": "stone-furnace", "x": 1.0, "y": 0.0}),
            observation=obs,
        )
        self.assertFalse(result.allowed)
        self.assertEqual(result.reason, "bot_inventory_missing_item")

    def test_place_in_range_is_allowed(self) -> None:
        obs = {
            "bot": {
                "position": {"x": 0.0, "y": 0.0},
                "inventory": [{"name": "stone-furnace", "count": 1}],
            },
            "entities": [],
        }
        result = validate_action(
            Action(type="place", params={"item": "stone-furnace", "x": 2.0, "y": 0.0}),
            observation=obs,
        )
        self.assertTrue(result.allowed)
        self.assertEqual(result.reason, "place_allowed")

    def test_place_rejects_occupied_target(self) -> None:
        obs = {
            "bot": {
                "position": {"x": 0.0, "y": 0.0},
                "inventory": [{"name": "stone-furnace", "count": 1}],
            },
            "entities": [
                {"unit_number": 10, "position": {"x": 2.0, "y": 0.0}},
            ],
        }
        result = validate_action(
            Action(type="place", params={"item": "stone-furnace", "x": 2.0, "y": 0.0}),
            observation=obs,
        )
        self.assertFalse(result.allowed)
        self.assertEqual(result.reason, "target_position_occupied")

    def test_insert_requires_target_entity(self) -> None:
        obs = {
            "bot": {
                "position": {"x": 0.0, "y": 0.0},
                "inventory": [{"name": "iron-plate", "count": 5}],
            },
            "entities": [],
        }
        result = validate_action(
            Action(type="insert", params={"item": "iron-plate", "target_unit_number": 99, "count": 1}),
            observation=obs,
        )
        self.assertFalse(result.allowed)
        self.assertEqual(result.reason, "target_entity_not_found")

    def test_insert_in_range_is_allowed(self) -> None:
        obs = {
            "bot": {
                "position": {"x": 0.0, "y": 0.0},
                "inventory": [{"name": "iron-plate", "count": 5}],
            },
            "entities": [
                {"unit_number": 11, "position": {"x": 2.0, "y": 0.0}},
            ],
        }
        result = validate_action(
            Action(type="insert", params={"item": "iron-plate", "target_unit_number": 11, "count": 3}),
            observation=obs,
        )
        self.assertTrue(result.allowed)
        self.assertEqual(result.reason, "insert_allowed")

    def test_take_requires_source_inventory_item(self) -> None:
        obs = {
            "bot": {"position": {"x": 0.0, "y": 0.0}, "inventory": []},
            "entities": [
                {
                    "unit_number": 12,
                    "position": {"x": 2.0, "y": 0.0},
                    "inventories": {"main": []},
                },
            ],
        }
        result = validate_action(
            Action(type="take", params={"item": "iron-plate", "target_unit_number": 12, "count": 1}),
            observation=obs,
        )
        self.assertFalse(result.allowed)
        self.assertEqual(result.reason, "target_inventory_missing_item")

    def test_take_in_range_is_allowed(self) -> None:
        obs = {
            "bot": {"position": {"x": 0.0, "y": 0.0}, "inventory": []},
            "entities": [
                {
                    "unit_number": 12,
                    "position": {"x": 2.0, "y": 0.0},
                    "inventories": {"main": [{"name": "iron-plate", "count": 4}]},
                },
            ],
        }
        result = validate_action(
            Action(type="take", params={"item": "iron-plate", "target_unit_number": 12, "count": 2}),
            observation=obs,
        )
        self.assertTrue(result.allowed)
        self.assertEqual(result.reason, "take_allowed")


if __name__ == "__main__":
    unittest.main()
