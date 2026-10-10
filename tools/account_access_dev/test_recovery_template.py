"""Regresiones de la comprobación parcial de Auth, sin conexión ni secretos."""
from copy import deepcopy
import unittest

from apply_recovery_template import CONFIRMATION_MARKERS, unexpected_properties


class RecoveryTemplateVerificationTests(unittest.TestCase):
    def setUp(self):
        self.before = {
            "mailer_subjects_recovery": "Reset your password",
            "mailer_subjects_custom_contents": {
                "MAILER_SUBJECTS_RECOVERY": False,
                "MAILER_SUBJECTS_CONFIRMATION": False,
            },
            "mailer_templates_custom_contents": {
                "MAILER_TEMPLATES_RECOVERY_CONTENT": False,
                "MAILER_TEMPLATES_CONFIRMATION_CONTENT": False,
            },
            "mailer_autoconfirm": False,
            "rate_limit_email_sent": 30,
        }
        self.after = deepcopy(self.before)
        self.after["mailer_subjects_recovery"] = "Restablece tu contraseña"
        self.after["mailer_subjects_custom_contents"]["MAILER_SUBJECTS_RECOVERY"] = True
        self.after["mailer_templates_custom_contents"]["MAILER_TEMPLATES_RECOVERY_CONTENT"] = True
        self.expected = {"mailer_subjects_recovery": "Restablece tu contraseña"}

    def test_accepts_only_server_recovery_markers(self):
        self.assertEqual(unexpected_properties(self.before, self.after, self.expected), [])

    def test_rejects_another_mail_changed_inside_marker_map(self):
        self.after["mailer_subjects_custom_contents"]["MAILER_SUBJECTS_CONFIRMATION"] = True
        self.assertEqual(unexpected_properties(self.before, self.after, self.expected),
                         ["mailer_subjects_custom_contents"])

    def test_rejects_confirmation_or_rate_limit_changes(self):
        self.after["mailer_autoconfirm"] = True
        self.after["rate_limit_email_sent"] = 1000
        self.assertEqual(unexpected_properties(self.before, self.after, self.expected),
                         ["mailer_autoconfirm", "rate_limit_email_sent"])

    def test_rejects_disabling_existing_custom_marker(self):
        self.assertEqual(unexpected_properties(self.after, self.before, self.expected),
                         ["mailer_subjects_custom_contents", "mailer_templates_custom_contents"])

    def test_rejects_an_unknown_marker_structure(self):
        self.after["mailer_templates_custom_contents"] = "unexpected"
        self.assertEqual(unexpected_properties(self.before, self.after, self.expected),
                         ["mailer_templates_custom_contents"])

    def test_accepts_confirmation_markers_only_when_confirmation_is_selected(self):
        after = deepcopy(self.before)
        for key, marker in CONFIRMATION_MARKERS.items():
            after[key][marker] = True
        self.assertEqual(unexpected_properties(self.before, after, {}, CONFIRMATION_MARKERS), [])
        self.assertEqual(unexpected_properties(self.before, after, {}),
                         ["mailer_subjects_custom_contents", "mailer_templates_custom_contents"])

    def test_confirmation_cannot_change_recovery_or_smtp(self):
        self.after["smtp_pass"] = "fixture-secret"
        self.assertEqual(unexpected_properties(self.before, self.after, self.expected, CONFIRMATION_MARKERS),
                         ["mailer_subjects_custom_contents", "mailer_templates_custom_contents", "smtp_pass"])


if __name__ == "__main__":
    unittest.main()
