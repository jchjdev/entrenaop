import unittest
from trainer_pricing_catalog import BASE, BANDS, RATES, REUSED, amount, catalogue, migration


class TrainerPricingTests(unittest.TestCase):
    def test_accepted_anchors_and_new_breakpoints(self):
        expected = {
            5: (1290, 1990, 2490), 7: (1490, 2230, 2770),
            10: (1790, 2590, 3190), 20: (2590, 3590, 4390),
            35: (3490, 4640, 5740), 50: (4090, 5390, 6790),
            75: (4965, 6515, 8165), 100: (5590, 7390, 9290),
        }
        for n, prices in expected.items():
            self.assertEqual(tuple(amount(tier, n) for tier in ('basic', 'professional', 'complete')), prices)

    def test_every_extra_seat_costs_less_as_volume_grows_without_repricing(self):
        for tier in BASE:
            previous_delta = None
            for n in range(6, 101):
                delta = amount(tier, n) - amount(tier, n-1)
                expected = next(rate for (first, last), rate in zip(BANDS, RATES[tier]) if first <= n <= last)
                self.assertEqual(delta, expected)
                self.assertGreater(delta, 0)
                if previous_delta is not None:
                    self.assertLessEqual(delta, previous_delta)
                self.assertLess(amount(tier, n) * (n-1), amount(tier, n-1) * n)
                previous_delta = delta
        for n in range(5, 101):
            self.assertEqual(amount('basic_directory', n)-amount('basic', n), 490)
            self.assertLess(amount('basic', n), amount('professional', n))
            self.assertLess(amount('professional', n), amount('complete', n))

    def test_no_fractional_out_of_range_or_boolean_capacity(self):
        for n in (4, 101, 5.0, True, '7', None):
            with self.assertRaises(ValueError):
                amount('basic', n)

    def test_catalogue_is_explicitly_sandbox_and_covers_every_quantity(self):
        cat = catalogue()
        self.assertTrue(cat['sandbox'])
        self.assertEqual([r['capacity'] for r in cat['monthly_prices']], list(range(5, 101)))
        self.assertEqual(cat['capacity_step'], 1)

    def test_seed_preserves_original_five_and_refuses_incomplete_or_incoherent_mapping(self):
        rows = [{'tier': tier, 'capacity': n, 'priceId': REUSED[tier][1] if n == 5 else f'price_fixture_{tier}_{n}', 'amount': amount(tier, n)} for tier in BASE for n in range(5, 101)]
        sql = migration(rows)
        self.assertEqual(sql.count('alumnos · ensayo'), 380)
        self.assertNotIn('delete ', sql.lower())
        self.assertNotIn('update commerce_private.orders', sql.lower())
        for oid, price in REUSED.values():
            self.assertIn(oid, sql)
            self.assertNotIn(price, sql)
        with self.assertRaises(ValueError):
            migration(rows[:-1])
        rows[1]['amount'] += 1
        with self.assertRaises(ValueError):
            migration(rows)


if __name__ == '__main__':
    unittest.main()
