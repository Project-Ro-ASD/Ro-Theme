#!/usr/bin/env python3
"""DNF işlem iptaliyle ağ/çözümleyici hatalarının ayrılmasını sınar."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

CHECK = Path(__file__).with_name("check-rpm-dependencies.sh").resolve()
RESOLVED = " ro-theme noarch 1.1.2 @commandline\nTransaction Summary:\n Installing: 1 package\nOperation aborted by the user.\n"


class DependencyCheck(unittest.TestCase):
    def check_result(self, output, status, succeeds):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            (root / "new.rpm").touch()
            (root / "output").write_text(output)
            stub = root / "dnf"
            stub.write_text(f'#!/bin/sh\ncat "{root}/output"\nexit {status}\n')
            stub.chmod(0o755)
            result = subprocess.run(["bash", str(CHECK), str(root / "new.rpm")],
                                    env=os.environ | {"PATH": str(root) + ":" + os.environ["PATH"]},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, succeeds, result.stdout + result.stderr)

    def test_resolved_transaction_cancelled(self):
        self.check_result(RESOLVED, 1, True)

    def test_metadata_network_failure(self):
        self.check_result("Failed to download metadata: Could not resolve host", 1, False)

    def test_missing_dependency(self):
        self.check_result("Problem: nothing provides missing-package", 1, False)

    def test_unknown_command(self):
        self.check_result("dnf: command not found", 127, False)

    def test_no_transaction(self):
        self.check_result("Nothing to do.", 0, False)

    def test_unexpected_status_with_partial_output(self):
        self.check_result(RESOLVED, 2, False)


if __name__ == "__main__":
    unittest.main()
