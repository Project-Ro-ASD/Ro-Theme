#!/usr/bin/env python3
"""Derleme kökünü ve spec'e göre doğru RPM'in teste gönderilmesini sınar."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("build-rpm.sh").resolve()


class RpmBuild(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.repo = self.root / "source"
        self.repo.mkdir()
        for name in (".github", "assets", "core", "dist", "docs", "platform", "scripts",
                     "tools/dev", "packaging", "LICENSES"):
            (self.repo / name).mkdir(parents=True, exist_ok=True)
        for name in ("README.md", "LICENSE", "packaging/ro-theme.spec"):
            (self.repo / name).touch()
        (self.repo / "VERSION").write_text("1.2.3\n")
        self.script = self.repo / "tools/dev/build-rpm.sh"
        shutil.copyfile(SCRIPT, self.script)
        for name in ("generate-theme.sh", "validate.sh"):
            path = self.repo / "scripts" / name
            path.write_text("#!/bin/bash\nexit 0\n")
            path.chmod(0o755)
        check = self.repo / "tools/dev/test-rpm.sh"
        check.write_text('#!/bin/bash\nprintf "%s" "$1" > "$RO_TEST_CHECKED"\nexit "${RO_TEST_CHECK_STATUS:-0}"\n')
        check.chmod(0o755)
        self.calls = self.root / "calls.jsonl"
        self.calls.touch()
        self.checked = self.root / "checked"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("bash", "dirname", "tr", "realpath", "mkdir", "mktemp", "rm", "cp",
                     "tar", "gzip", "find", "sort", "tail", "sed"):
            (self.bin / name).symlink_to(shutil.which(name))
        stub = self.bin / "rpm-stub"
        stub.write_text(f'#!{sys.executable}\n' + '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
tool = Path(sys.argv[0]).name
macros = dict(args[i+1].split(" ", 1) for i, arg in enumerate(args) if arg == "--define")
with open(os.environ["RO_TEST_CALLS"], "a") as log:
    log.write(json.dumps([tool, macros]) + "\\n")
name = "ro-theme-1.2.3-1" + macros["dist"] + ".noarch.rpm"
if tool == "rpmspec":
    print(os.environ.get("RO_TEST_QUERY_OUTPUT", name))
    sys.exit(int(os.environ.get("RO_TEST_QUERY_STATUS", "0")))
status = int(os.environ.get("RO_TEST_BUILD_STATUS", "0"))
if status == 0 and not os.environ.get("RO_TEST_SKIP_OUTPUT"):
    artifact = Path(macros["_topdir"]) / "RPMS/noarch" / name
    artifact.parent.mkdir(parents=True, exist_ok=True)
    artifact.touch()
sys.exit(status)
''')
        stub.chmod(0o755)
        (self.bin / "rpmbuild").symlink_to(stub.name)
        (self.bin / "rpmspec").symlink_to(stub.name)
        self.tmp = self.root / "tmp"
        self.tmp.mkdir()
        self.env = os.environ | {"PATH": str(self.bin), "TMPDIR": str(self.tmp),
                                 "RO_TEST_CALLS": str(self.calls), "RO_TEST_CHECKED": str(self.checked),
                                 "FEDORA_RELEASE": "44"}
        self.env.pop("RPMBUILD_TOPDIR", None)

    def build(self):
        return subprocess.run([str(self.bin / "bash"), str(self.script)], cwd=self.root,
                              env=self.env, capture_output=True, text=True)

    def assert_built(self, topdir, release="44"):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        expected = topdir / f"RPMS/noarch/ro-theme-1.2.3-1.fc{release}.noarch.rpm"
        self.assertEqual(self.checked.read_text(), str(expected))
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual([tool for tool, _ in calls], ["rpmspec", "rpmbuild"])
        self.assertEqual(calls[0][1], calls[1][1])
        self.assertEqual(calls[1][1]["_topdir"], str(topdir))
        self.assertTrue((topdir / "SOURCES/ro-theme-1.2.3.tar.gz").is_file())
        self.assertEqual(list(self.tmp.iterdir()), [])

    def test_default_absolute_build_root(self):
        self.assert_built(self.repo / "build/rpmbuild")

    def test_relative_build_root_is_resolved_from_repository(self):
        self.env["RPMBUILD_TOPDIR"] = "build/custom-rpmbuild"
        self.assert_built(self.repo / "build/custom-rpmbuild")

    def test_absolute_custom_build_root(self):
        self.env["RPMBUILD_TOPDIR"] = str(self.root / "custom")
        self.assert_built(self.root / "custom")

    def test_other_fedora_future_timestamp_does_not_change_selected_output(self):
        topdir = self.repo / "build/rpmbuild"
        old = topdir / "RPMS/noarch/ro-theme-1.2.3-1.fc43.noarch.rpm"
        old.parent.mkdir(parents=True)
        old.touch()
        os.utime(old, (2000000000, 2000000000))
        self.assert_built(topdir)
        self.assertTrue(old.exists())

    def test_custom_fedora_macro_is_shared_by_query_and_build(self):
        self.env["FEDORA_RELEASE"] = "43"
        self.assert_built(self.repo / "build/rpmbuild", release="43")

    def test_expected_output_missing_does_not_fall_back_to_old_package(self):
        old = self.repo / "build/rpmbuild/RPMS/noarch/ro-theme-1.2.3-1.fc43.noarch.rpm"
        old.parent.mkdir(parents=True)
        old.touch()
        self.env["RO_TEST_SKIP_OUTPUT"] = "1"
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected RPM file was not found", result.stderr)
        self.assertFalse(self.checked.exists())

    def test_build_error_never_tests_stale_output(self):
        self.env["RO_TEST_BUILD_STATUS"] = "8"
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.checked.exists())
        self.assertNotIn("RPM ready:", result.stdout)

    def test_spec_query_failure_stops_before_build(self):
        self.env["RO_TEST_QUERY_STATUS"] = "5"
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.calls.read_text().splitlines()), 1)
        self.assertFalse(self.checked.exists())

    def test_multiple_or_wrong_package_outputs_are_rejected(self):
        for output in ("ro-theme-1.2.3-1.fc44.noarch.rpm\nextra-1-1.noarch.rpm",
                       "ro-theme-1.2.3-1.fc44.x86_64.rpm", "other-1.2.3-1.fc44.noarch.rpm"):
            with self.subTest(output=output):
                self.calls.write_text("")
                self.env["RO_TEST_QUERY_OUTPUT"] = output
                self.assertNotEqual(self.build().returncode, 0)
                self.assertEqual(len(self.calls.read_text().splitlines()), 1)
                self.assertFalse(self.checked.exists())

    def test_missing_rpm_tools_report_failure(self):
        for tool in ("rpmspec", "rpmbuild"):
            with self.subTest(tool=tool):
                path = self.bin / tool
                path.unlink()
                result = self.build()
                self.assertEqual(result.returncode, 2)
                self.assertIn(f"{tool} command not found", result.stderr)
                self.assertFalse(self.checked.exists())
                path.symlink_to("rpm-stub")


if __name__ == "__main__":
    unittest.main()
