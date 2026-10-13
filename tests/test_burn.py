#!/usr/bin/env python3
"""burn() 回归测试 —— 充值不得抹平窗口内的消耗统计。

跑法：python3 tests/test_burn.py
"""
import importlib.machinery
import importlib.util
import json
import pathlib
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin" / "ds-balance"


def load_script():
    loader = importlib.machinery.SourceFileLoader("ds_balance", str(SCRIPT))
    spec = importlib.util.spec_from_loader("ds_balance", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class BurnTest(unittest.TestCase):
    def setUp(self):
        self.mod = load_script()
        self.tmp = tempfile.TemporaryDirectory()
        self.hist = pathlib.Path(self.tmp.name) / "history.jsonl"
        self.mod.HIST = self.hist
        self.now = time.time()

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, points):
        """points: [(seconds_ago, total)] -> 逐行写进 history"""
        with open(self.hist, "w") as f:
            for ago, total in points:
                f.write(json.dumps({"ts": self.now - ago, "cny": {"total": total}}) + "\n")

    def test_pure_spend(self):
        self.write([(3000, 10.0), (2000, 9.5), (1000, 9.0)])
        self.assertAlmostEqual(self.mod.burn(3600), 1.0, places=6)

    def test_topup_does_not_erase_spend(self):
        # 旧写法（窗口首尾差值 + max(0,…)）：9.6 - 59.5 < 0 → 0，充值抹平整段消耗
        self.write([(3000, 10.0), (2000, 9.6), (1000, 59.6), (500, 59.5)])
        self.assertAlmostEqual(self.mod.burn(3600), 0.5, places=6)

    def test_topup_only(self):
        self.write([(1000, 10.0), (500, 60.0)])
        self.assertAlmostEqual(self.mod.burn(3600), 0.0, places=6)

    def test_points_outside_window_ignored(self):
        # 24 小时前的高余额不该影响 1 小时窗口
        self.write([(100000, 100.0), (3000, 10.0), (1000, 9.0)])
        self.assertAlmostEqual(self.mod.burn(3600), 1.0, places=6)

    def test_single_point_is_none(self):
        self.write([(1000, 10.0)])
        self.assertIsNone(self.mod.burn(3600))

    def test_missing_history_is_none(self):
        self.hist.unlink(missing_ok=True)
        self.assertIsNone(self.mod.burn(3600))


if __name__ == "__main__":
    unittest.main(verbosity=2)
