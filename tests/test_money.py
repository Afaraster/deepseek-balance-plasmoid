#!/usr/bin/env python3
"""money() 格式化测试 —— 金额只到分，且不足一分的正数不被显示成 0.00。

跑法：python3 tests/test_money.py
"""
import importlib.machinery
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin" / "ds-balance"


def load_script():
    loader = importlib.machinery.SourceFileLoader("ds_balance", str(SCRIPT))
    spec = importlib.util.spec_from_loader("ds_balance", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class MoneyTest(unittest.TestCase):
    def setUp(self):
        self.money = load_script().money

    def test_two_decimals(self):
        self.assertEqual(self.money(4.099999999999998), "4.10")
        self.assertEqual(self.money(0.28), "0.28")
        self.assertEqual(self.money(0.0), "0.00")
        self.assertEqual(self.money(63.64), "63.64")

    def test_rounds_to_cents(self):
        self.assertEqual(self.money(0.0049), "<0.01")
        self.assertEqual(self.money(0.005), "0.01")
        self.assertEqual(self.money(1.005), "1.00")  # 二进制浮点，符合预期

    def test_sub_cent_positive_is_not_zero(self):
        self.assertEqual(self.money(0.001), "<0.01")

    def test_none(self):
        self.assertEqual(self.money(None), "—")


if __name__ == "__main__":
    unittest.main(verbosity=2)
