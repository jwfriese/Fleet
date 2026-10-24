import pathlib
import re
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]


class PilotDocumentationTests(unittest.TestCase):
    def test_documented_viewinspector_revision_matches_checker(self):
        checker = (REPO / "script/check_distribution.py").read_text()
        revision = re.search(r'VIEWINSPECTOR_REVISION = "([0-9a-f]{40})"', checker).group(1)
        for page in ("Compatibility.md", "ViewInspector.md"):
            self.assertIn(revision, (REPO / "Documentation" / page).read_text(), page)

    def test_migration_guide_covers_pilot_topics_and_selects_no_version(self):
        text = (REPO / "Documentation/Migration.md").read_text()
        for needle in ("FLEET_HOSTING_POLICY=preserve-timing", "withHostedView", "addCleanup",
                       "FleetFailure(.timedOut)", "script/release publish", "revision"):
            self.assertIn(needle, text)
        self.assertIn("nothing here selects a version", text)


if __name__ == "__main__":
    unittest.main()
