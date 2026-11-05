"""Verifica que la migración importa la referencia FAS sin reinterpretarla."""

import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / "supabase/migrations/20261105180858_builtin_assessment_authoring.sql"


class BuiltinAssessmentSeedTest(unittest.TestCase):
    def setUp(self):
        self.asset = json.loads(
            (ROOT / "assets/programs/fas_periodic_2027/assessment_reference_v1.json").read_text(
                encoding="utf-8"
            )
        )
        sql = MIGRATION.read_text(encoding="utf-8")
        literal = re.search(r"\$fas_seed\$(.*?)\$fas_seed\$", sql, re.S)
        self.assertIsNotNone(literal)
        self.seed = json.loads(literal.group(1))

    def test_original_reference_is_identical_including_literal_anomalies(self):
        for key, value in self.asset.items():
            self.assertEqual(self.seed[key], value, key)
        self.assertEqual(sum(len(t["rows"]) for t in self.seed["tests"]), 306)
        self.assertEqual(
            set(self.seed) - set(self.asset), {"schemaVersion", "name", "description"}
        )

    def test_all_64_projected_minimums_equal_original_sql(self):
        original_sql = (
            ROOT / "supabase/migrations/20260923006000_fas_periodic_assessments.sql"
        ).read_text(encoding="utf-8")
        original = {
            (test, band, category): int(value)
            for test, band, category, value in re.findall(
                r"\('es_def_15_2026_periodic_2027_v1', '([^']+)', '([^']+)', '(men|women)', (\d+)\)",
                original_sql,
            )
        }
        projected = {}
        for test in self.seed["tests"]:
            bands = test.get("ageBands", [b["id"] for b in self.seed["ageBands"]])
            for band_index, band in enumerate(bands):
                for category_index, category in enumerate(["men", "women"]):
                    column = (
                        band_index * 2 + category_index
                        if test["categoriesPerAgeBand"]
                        else band_index
                    )
                    passing = [
                        row[0]
                        for row in test["rows"]
                        if row[1][column] >= self.seed["minimumPointsPerTest"]
                    ]
                    projected[test["id"], band, category] = (
                        min(passing) if test["betterDirection"] == "higher" else max(passing)
                    )
        self.assertEqual(len(projected), 64)
        self.assertEqual(projected, original)

    def test_private_implementations_and_public_invoker_boundaries(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        for match in re.finditer(
            r"create(?: or replace)? function public\.(\w+).*?\bas \$\$", sql, re.S | re.I
        ):
            self.assertIn("security invoker", match.group(0).lower(), match.group(1))
        self.assertIn("revoke all on all functions in schema builtin_assessment_private", sql)
        smoke = (ROOT / "supabase/tests/builtin_assessment_authoring_smoke.sql").read_text(
            encoding="utf-8"
        )
        self.assertTrue(smoke.rstrip().endswith("rollback;"))


if __name__ == "__main__":
    unittest.main()
