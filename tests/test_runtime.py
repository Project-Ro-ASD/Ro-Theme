import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests import fakes
from tests.helpers import ROOT  # noqa: F401
from rotheme import manifest, runtime
from rotheme.cli import build_parser


def parse(*args):
    return build_parser().parse_args(list(args))


class RuntimeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.home = self.base / "home"
        self.data = self.base / "data"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.env = {"HOME": str(self.home), "XDG_DATA_HOME": str(self.data),
                    "XDG_DATA_DIRS": str(self.base / "system"),
                    "QT_PLUGIN_PATH": "", "PATH": str(self.bin)}
        self.plugin_patch = mock.patch.object(runtime, "_plugin_dirs", lambda env: [])
        self.plugin_patch.start()

    def tearDown(self):
        self.plugin_patch.stop()
        self.tmp.cleanup()

    def plasmoid(self, applet):
        base = self.data / "plasma/plasmoids" / applet
        fakes.write(base / "metadata.json", "{}")
        fakes.write(base / "contents/ui/main.qml", "//\n")

    def test_layout_ok(self):
        for applet in manifest.RUNTIME_APPLETS["layout"]["required"]:
            self.plasmoid(applet)
        with mock.patch.dict(os.environ, self.env, clear=False):
            self.assertEqual(runtime.main(parse("check-runtime", "layout")), 0)

    def test_missing_required_fails_with_message(self):
        for applet in manifest.RUNTIME_APPLETS["layout"]["required"][1:]:
            self.plasmoid(applet)
        with mock.patch.dict(os.environ, self.env, clear=False), mock.patch("sys.stderr") as stderr:
            self.assertEqual(runtime.main(parse("check-runtime", "layout")), 1)
        text = "".join(str(c) for c in stderr.write.call_args_list)
        self.assertIn("Unsafe to apply the full Ro panel layout", text)

    def test_popups_optional_missing_is_warning(self):
        self.plasmoid("org.kde.plasma.systemtray")
        with mock.patch.dict(os.environ, self.env, clear=False):
            self.assertEqual(runtime.main(parse("check-runtime", "popups")), 0)
        results = runtime.check("popups", self.env)
        self.assertTrue(any(r.status == "WARN" for r in results))

    def test_kpackagetool6_is_primary_source(self):
        fakes.tool(self.bin, "kpackagetool6", 'exit 0')
        with mock.patch.dict(os.environ, self.env, clear=False):
            self.assertEqual(runtime.main(parse("check-runtime", "layout")), 0)
        self.assertTrue(all(r.source == "kpackagetool6" for r in runtime.check("layout", self.env)
                            if r.status == "OK"))

    def test_json_output(self):
        self.plasmoid("org.kde.plasma.systemtray")
        out = io.StringIO()
        with mock.patch.dict(os.environ, self.env, clear=False), mock.patch("sys.stdout", out):
            self.assertEqual(runtime.main(parse("check-runtime", "popups", "--json")), 0)
        payload = json.loads(out.getvalue())
        self.assertEqual(payload["mode"], "popups")
        self.assertIn("results", payload)

    def test_invalid_mode_exits_2(self):
        with self.assertRaises(SystemExit) as caught:
            parse("check-runtime", "bozuk")
        self.assertEqual(caught.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
