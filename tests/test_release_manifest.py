import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from rotheme import release_manifest


RPM_SCRIPT = """#!/bin/sh
for last do :; done
case "$last" in
  *.src.rpm)
    printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s' ro-theme 0 2.0.0 1.fc44 src '(none)' true ;;
  *)
    printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s' ro-theme 0 2.0.0 1.fc44 noarch ro-theme-2.0.0-1.fc44.src.rpm false ;;
esac
"""

ENV = {
    "GITHUB_REPOSITORY": "Project-Ro-ASD/Ro-Theme",
    "GITHUB_SHA": "a" * 40,
    "TAG": "v2.0.0",
    "RELEASE_ID": "42",
    "GITHUB_RUN_ID": "1234",
}


def write_exec(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    path.chmod(0o755)


class ReleaseManifestTest(unittest.TestCase):
    def make_bundle(self, d: Path) -> Path:
        bundle = d / "bundle"
        bundle.mkdir()
        (bundle / "ro-theme-2.0.0-1.fc44.noarch.rpm").write_bytes(b"ikili")
        (bundle / "ro-theme-2.0.0-1.fc44.src.rpm").write_bytes(b"kaynak")
        bin = d / "bin"
        bin.mkdir()
        write_exec(bin / "rpm", RPM_SCRIPT)
        return bundle

    def test_manifest_fields_order_and_sums(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            bundle = self.make_bundle(d)
            with mock.patch.dict(os.environ, {**ENV, "PATH": f"{d / 'bin'}:/usr/bin:/bin"}):
                data = release_manifest.build(bundle)

            self.assertEqual(data["schema_version"], 1)
            self.assertEqual(data["component"], "ro-theme")
            self.assertEqual(data["source_repository"], ENV["GITHUB_REPOSITORY"])
            self.assertEqual(data["source_commit"], ENV["GITHUB_SHA"])
            self.assertEqual(data["release_tag"], "v2.0.0")
            self.assertEqual(data["release_id"], 42)
            self.assertEqual(data["workflow_run"], 1234)
            self.assertEqual(data["fedora_release"], 44)
            self.assertEqual(data["provenance"], {"provider": "github", "subject_digest": "sha256"})
            self.assertEqual(data["attestation"],
                             {"provider": "github", "verification": "gh attestation verify"})

            names = [a["filename"] for a in data["artifacts"]]
            self.assertEqual(names, sorted(names))
            self.assertEqual([a["architecture"] for a in data["artifacts"]], ["noarch", "src"])
            self.assertIsNone(data["artifacts"][1]["source_rpm"])
            self.assertEqual(data["artifacts"][0]["source_rpm"], "ro-theme-2.0.0-1.fc44.src.rpm")

            text = (bundle / release_manifest.MANIFEST_NAME).read_text(encoding="utf-8")
            self.assertEqual(text, json.dumps(data, indent=2, sort_keys=True) + "\n")
            self.assertTrue(text.startswith('{\n  "artifacts":'))

            sums = (bundle / "SHA256SUMS").read_text(encoding="utf-8")
            expected = ""
            for name in names:
                digest = hashlib.sha256((bundle / name).read_bytes()).hexdigest()
                expected += f"{digest}  {name}\n"
            self.assertEqual(sums, expected)

    def test_missing_environment_variable_fails(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            bundle = self.make_bundle(d)
            env = {k: v for k, v in ENV.items() if k != "GITHUB_REPOSITORY"}
            env["PATH"] = f"{d / 'bin'}:/usr/bin:/bin"
            with mock.patch.dict(os.environ, env, clear=True):
                with self.assertRaises(SystemExit):
                    release_manifest.build(bundle)

    def test_empty_bundle_fails(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            bundle = d / "bundle"
            bundle.mkdir()
            with mock.patch.dict(os.environ, ENV):
                with self.assertRaises(SystemExit):
                    release_manifest.build(bundle)


if __name__ == "__main__":
    unittest.main()
