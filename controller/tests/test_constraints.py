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

    def test_move_too_far_is_rejected(self) -> None:
        obs = {"bot": {"position": {"x": 0.0, "y": 0.0}}}
        result = validate_action(Action(type="move", params={"x": 1000.0, "y": 0.0}), observation=obs)
        self.assertFalse(result.allowed)

    def test_move_in_range_is_allowed(self) -> None:
        obs = {"bot": {"position": {"x": 0.0, "y": 0.0}}}
        result = validate_action(Action(type="move", params={"x": 10.0, "y": 0.0}), observation=obs)
        self.assertTrue(result.allowed)


if __name__ == "__main__":
    unittest.main()
