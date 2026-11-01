import unittest

from tests.helpers import ROOT
from rotheme import generate, tokens


class QmlTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = generate.Context(tokens.load(ROOT), ROOT)
        cls.files = generate.collect(cls.ctx, ("qml",))

    def test_rotokens_depodakiyle_bayt_bayt_ayni(self):
        path = "dist/qml/RoTokens.qml"
        self.assertEqual(len(self.files), 1)
        self.assertEqual(self.files[path], (ROOT / path).read_bytes())


if __name__ == "__main__":
    unittest.main()
