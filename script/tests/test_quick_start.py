import pathlib
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]


class QuickStartTests(unittest.TestCase):
    def test_documented_quick_start_matches_compiled_consumer_source(self):
        source = (REPO / "Integration/PackageConsumer/SwiftTestingConsumerTests.swift").read_text()
        compiled = source.split("// quick-start:begin\n")[1].split("// quick-start:end")[0].strip("\n")
        page = (REPO / "Documentation/QuickStart.md").read_text()
        block = page.split("```swift\n")[1].split("\n```")[0]
        self.assertEqual(block, compiled)

    def test_documented_xctest_starter_matches_compiled_consumer_source(self):
        source = (REPO / "Integration/PackageConsumer/PackageConsumerTests.swift").read_text()
        compiled = source.split("// xctest-starter:begin\n")[1].split("// xctest-starter:end")[0].strip("\n")
        page = (REPO / "Documentation/QuickStart.md").read_text()
        block = page.split("```swift\n")[2].split("\n```")[0]
        self.assertEqual(block, compiled)


if __name__ == "__main__":
    unittest.main()
