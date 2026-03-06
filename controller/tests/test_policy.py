from __future__ import annotations

import unittest

from fwai.policies.mvp_space_policy import MVPSpacePolicy


class PolicyTests(unittest.TestCase):
    def test_spawns_bot_when_missing(self) -> None:
        policy = MVPSpacePolicy()
        action = policy.decide({})
        self.assertEqual(action.type, "spawn_bot")

    def test_waits_when_bot_exists(self) -> None:
        policy = MVPSpacePolicy()
        action = policy.decide({"bot": {"unit_number": 1}})
        self.assertEqual(action.type, "wait")


if __name__ == "__main__":
    unittest.main()
