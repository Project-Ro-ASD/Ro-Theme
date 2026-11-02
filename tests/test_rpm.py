import gzip
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from tests.helpers import ROOT
from rotheme import rpm


def write_exec(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    path.chmod(0o755)


class RpmBuildTest(unittest.TestCase):
    def test_tarball_is_reproducible_gzip(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            root = d / "repo"
            (root / "packaging").mkdir(parents=True)
            (root / "VERSION").write_text("2.0.0\n")
            (root / "packaging/ro-theme.spec").write_text("Name: ro-theme\n")
            bin = d / "bin"
            bin.mkdir()
            write_exec(bin / "git", "#!/bin/sh\nprintf 'arsiv-icerigi'\n")
            write_exec(bin / "rpmbuild", "#!/bin/sh\nexit 0\n")
            topdir = d / "topdir"
            args = SimpleNamespace(topdir=topdir, container=False, rpm_command="build")

            with mock.patch.dict(os.environ, {"PATH": f"{bin}:/usr/bin:/bin"}):
                self.assertEqual(rpm.build(args, root=root), 0)

            tarball = topdir / "SOURCES" / "ro-theme-2.0.0.tar.gz"
            self.assertTrue(tarball.is_file())
            data = tarball.read_bytes()
            self.assertEqual(data[4:8], b"\x00\x00\x00\x00")   # gzip -n: mtime yok
            self.assertEqual(gzip.decompress(data), b"arsiv-icerigi")

    def test_container_without_image_fails_without_pull(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            bin = d / "bin"
            bin.mkdir()
            write_exec(bin / "podman", "#!/bin/sh\nexit 1\n")
            args = SimpleNamespace(topdir=d / "topdir", container=True, rpm_command="build")
            with mock.patch.dict(os.environ, {"PATH": f"{bin}:/usr/bin:/bin"}):
                self.assertEqual(rpm.build(args, root=d), 2)


RPM_SCRIPT = """#!/bin/sh
case "$*" in
  *--requires*) cat "$RPM_FIXTURE/requires" ;;
  *--qf*FILENAMES*) cat "$RPM_FIXTURE/files" ;;
  *--qf*) cat "$RPM_FIXTURE/meta" ;;
  *) exit 1 ;;
esac
"""


class RpmCheckTest(unittest.TestCase):
    def run_check(self, mutate=None) -> int:
        files, dirs = rpm.expected_paths(ROOT)
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            fixture = d / "fixture"
            fixture.mkdir()
            (fixture / "meta").write_text(f"ro-theme\t{(ROOT / 'VERSION').read_text().strip()}\t1.fc44\tnoarch\n")
            (fixture / "requires").write_text(
                "google-noto-sans-fonts\ngoogle-noto-sans-mono-fonts\nrsms-inter-fonts\n"
                "papirus-icon-theme\npapirus-icon-theme-dark\npapirus-icon-theme-light\n")
            lines = [f"{p}\t0100644" for p in sorted(files)]
            lines += [f"{p}\t040755" for p in sorted(dirs | {"/usr/share", "/usr"})]
            if mutate:
                lines = mutate(lines)
            (fixture / "files").write_text("\n".join(lines) + "\n")

            bin = d / "bin"
            bin.mkdir()
            write_exec(bin / "rpm", RPM_SCRIPT)
            package = d / "ro-theme.rpm"
            package.write_bytes(b"rpm")
            args = SimpleNamespace(rpm=package, topdir=d, rpm_command="check")
            with mock.patch.dict(os.environ, {"PATH": f"{bin}:/usr/bin:/bin",
                                              "RPM_FIXTURE": str(fixture)}):
                return rpm.check(args, root=ROOT)

    def test_valid_package_passes(self):
        self.assertEqual(self.run_check(), 0)

    def test_missing_file_fails(self):
        missing = sorted(rpm.expected_paths(ROOT)[0])[0]

        def drop(lines):
            return [line for line in lines if not line.startswith(missing + "\t")]
        self.assertEqual(self.run_check(drop), 1)

    def test_unexpected_file_fails(self):
        self.assertEqual(self.run_check(lambda lines: lines + ["/usr/share/ro-theme/artik\t0100644"]), 1)


if __name__ == "__main__":
    unittest.main()
