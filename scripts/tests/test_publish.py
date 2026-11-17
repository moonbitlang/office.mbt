"""Exercise release ordering, index propagation, and resume without a registry."""

from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("publish", ROOT / "scripts/ci/publish.py")
publish = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(publish)

FAKE_MOON = '''
import json, os, pathlib, sys

state_path = pathlib.Path(os.environ["PUBLISH_TEST_STATE"])
state = json.loads(state_path.read_text())
index = pathlib.Path(os.environ["MOON_HOME"]) / "registry/index"

def finish(code=0):
    state_path.write_text(json.dumps(state))
    sys.exit(code)

if sys.argv[1:] == ["update"]:
    state["updates"] += 1
    if state["updates"] == state.get("fail_update_at"):
        finish(7)
    if not state.get("missing_index"):
        index.mkdir(parents=True, exist_ok=True)
    for coordinate, visible_after in state["releases"].items():
        if visible_after > state["updates"]:
            continue
        name, version = coordinate.split("@")
        path = index / "user" / (name + ".index")
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a") as output:
            output.write(json.dumps({"name": name, "version": version}) + "\\n")
    finish()

if sys.argv[1:] == ["publish"]:
    module = pathlib.Path.cwd().name
    entry = state["modules"][module]
    coordinate = entry["coordinate"]
    if coordinate in state["releases"] or module == state.get("fail_publish"):
        finish(8)
    # Model the extracted archive check: workspace members cannot satisfy it.
    for dependency in entry["requires"]:
        name, version = dependency.split("@")
        path = index / "user" / (name + ".index")
        if not path.exists() or not any(
            json.loads(line)["version"] == version for line in path.read_text().splitlines()
        ):
            finish(9)
    state["published"].append(coordinate)
    state["releases"][coordinate] = state["updates"] + state["index_delay"]
    finish()

finish(10)
'''


class PublishTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.moon_home = self.root / "moon-home"
        self.state_path = self.root / "state.json"
        self.state = {
            "updates": 0,
            "index_delay": 1,
            "published": [],
            "releases": {},
            "modules": {},
        }
        self.add_module("ooxml", "moonbitlang/ooxml", "0.1.2")
        self.add_module("mbtexcel", "moonbitlang/mbtexcel", "0.3.2")
        self.add_module("docx2html", "moonbitlang/docx2html", "0.7.2", ["moonbitlang/ooxml@0.1.2"])
        self.add_module("office-cli", "moonbitlang/office", "0.3.2", [
            "moonbitlang/ooxml@0.1.2", "moonbitlang/mbtexcel@0.3.2",
        ])
        binaries = self.root / "bin"
        binaries.mkdir()
        moon = binaries / "moon"
        moon.write_text(f"#!{sys.executable}\n" + FAKE_MOON)
        moon.chmod(0o755)
        self.environment = {
            "PATH": str(binaries) + os.pathsep + os.environ["PATH"],
            "MOON_HOME": str(self.moon_home),
            "PUBLISH_TEST_STATE": str(self.state_path),
        }

    def add_module(self, directory, name, version, requires=None):
        path = self.root / directory
        path.mkdir()
        (path / "moon.mod").write_text(f'name = "{name}"\n\nversion = "{version}"\n')
        self.state["modules"][directory] = {
            "coordinate": f"{name}@{version}", "requires": requires or [],
        }

    def run_publish(self, modules):
        self.state_path.write_text(json.dumps(self.state))
        try:
            with patch.dict(os.environ, self.environment), redirect_stdout(io.StringIO()):
                with patch.object(publish.time, "sleep") as sleep:
                    publish.publish_modules(self.root, modules, self.moon_home)
                    return sleep.call_count
        finally:
            self.state = json.loads(self.state_path.read_text())

    def test_waits_for_new_dependency_in_refreshed_index(self):
        self.state["releases"]["moonbitlang/ooxml@0.1.1"] = 0
        self.state["index_delay"] = 3
        sleeps = self.run_publish(["ooxml", "docx2html"])
        self.assertEqual(self.state["published"], [
            "moonbitlang/ooxml@0.1.2", "moonbitlang/docx2html@0.7.2",
        ])
        self.assertGreater(sleeps, 0)

    def test_resume_skips_exact_versions_and_maps_cli_name(self):
        self.state["releases"] = {
            "moonbitlang/ooxml@0.1.2": 0,
            "moonbitlang/mbtexcel@0.3.2": 0,
            "moonbitlang/office@0.3.1": 0,
        }
        modules = ["ooxml", "mbtexcel", "office-cli"]
        self.run_publish(modules)
        self.assertEqual(self.state["published"], ["moonbitlang/office@0.3.2"])
        self.run_publish(modules)
        self.assertEqual(self.state["published"], ["moonbitlang/office@0.3.2"])

    def test_index_timeout_stops_before_consumer(self):
        self.state["index_delay"] = 100
        with patch.object(publish, "INDEX_ATTEMPTS", 3):
            with self.assertRaisesRegex(RuntimeError, "absent.*after 3 refreshes"):
                self.run_publish(["ooxml", "docx2html"])
        self.assertEqual(self.state["published"], ["moonbitlang/ooxml@0.1.2"])

    def test_update_failure_stops_release(self):
        # Both the initial refresh and a refresh after upload must fail closed.
        for failed_update in (1, 2):
            with self.subTest(failed_update=failed_update):
                self.state["updates"] = 0
                self.state["releases"] = {}
                self.state["published"] = []
                self.state["fail_update_at"] = failed_update
                with self.assertRaises(subprocess.CalledProcessError):
                    self.run_publish(["ooxml", "docx2html"])
                expected = [] if failed_update == 1 else ["moonbitlang/ooxml@0.1.2"]
                self.assertEqual(self.state["published"], expected)

    def test_publish_failure_is_not_skipped(self):
        self.state["fail_publish"] = "ooxml"
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_publish(["ooxml", "docx2html"])
        self.assertEqual(self.state["published"], [])

    def test_missing_index_stops_before_upload(self):
        self.state["missing_index"] = True
        with self.assertRaisesRegex(RuntimeError, "Git registry index is missing"):
            self.run_publish(["ooxml"])
        self.assertEqual(self.state["published"], [])


if __name__ == "__main__":
    unittest.main()
