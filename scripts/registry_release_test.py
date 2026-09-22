#!/usr/bin/env python3
"""Regression checks for isolated release staging and fail-closed publish gates."""

from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

from registry_release import check_archive, dependency_version, stage


ROOT = Path(__file__).resolve().parent.parent


class RegistryReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)

    def shell(self, script):
        return subprocess.run(
            ["bash", "-euo", "pipefail", "-c", script, "--", str(ROOT), str(self.path)],
            capture_output=True, text=True,
        )

    def test_versions_come_from_manifest_and_missing_requirements_fail(self):
        manifest = self.path / "moon.mod"
        manifest.write_text('import {\n "moonbitlang/mbtexcel@0.2.0",\n}\n'
                            '// "moonbitlang/mbtexcel@0.1.9"\n')
        self.assertEqual(dependency_version(manifest, "moonbitlang/mbtexcel"), "0.2.0")
        with self.assertRaises(ValueError):
            dependency_version(manifest, "moonbitlang/office-lib")

    def test_transitive_conflict_and_missing_tree_selection_fail(self):
        prefix = 'source "$1/scripts/release_tree_guard.sh"\n'
        good = 'moonbitlang/mbtexcel -> moonbitlang/mbtexcel@0.2.0'
        bad = 'moonbitlang/mbtexcel -> moonbitlang/mbtexcel@0.1.9'
        for tree, expected in [(good, 0), (good + '\n' + bad, 1), ('unrelated', 1)]:
            with self.subTest(tree=tree):
                result = self.shell(prefix + f'assert_selected_dependency "{tree}" moonbitlang/mbtexcel 0.2.0')
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_staging_excludes_ignored_builds_and_preserves_local_edits(self):
        repo = self.path / "repo"
        repo.mkdir()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        (repo / "moon.work").write_text('members = ["./module"]\n')
        (repo / ".gitignore").write_text('_build/\n.mooncakes/\n')
        module = repo / "module"
        module.mkdir()
        (module / "moon.mod").write_text('name = "example/module"\n')
        subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
        (module / "moon.mod").write_text('name = "example/edited"\n')
        for directory in ["_build", ".mooncakes"]:
            (module / directory).mkdir()
            (module / directory / "artifact").write_text("build output")
        destination = self.path / "sandbox" / "module"
        stage(repo, "module", destination)
        self.assertEqual([p.name for p in destination.iterdir()], ["moon.mod"])
        self.assertIn("edited", (destination / "moon.mod").read_text())
        with self.assertRaises(ValueError):
            stage(repo, "module", repo / "nested-sandbox" / "module")

    def test_office_sandbox_has_fixtures_without_sibling_module(self):
        result = self.shell('''
ROOT="$1" SANDBOX="$2" MODULE="$2/office-lib"
source "$ROOT/scripts/registry_release.sh"
stage_registry_module office-lib
stage_registry_docx_fixtures
test -f "$SANDBOX/docx2html/tests/cram/fixtures/single-paragraph.docx"
test -f "$SANDBOX/docx2html/tests/cram/fixtures/commented.docx"
test -f "$SANDBOX/docx2html/tests/cram/fixtures/header-footer.docx"
test ! -e "$SANDBOX/docx2html/moon.mod"
test ! -e "$SANDBOX/moon.work"
grep -Fxq '_build/' "$MODULE/.gitignore"
grep -Fxq '.mooncakes/' "$MODULE/.gitignore"
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_archive_rejects_build_output_even_under_module_prefix(self):
        for entry in ["_build/native/test.exe", "pkg/.mooncakes/dependency/moon.mod",
                      "pkg/target/file", "pkg/.tools/sdk", "../escape"]:
            with self.subTest(entry=entry):
                archive_path = self.path / "candidate.zip"
                with zipfile.ZipFile(archive_path, "w") as archive:
                    archive.writestr("moon.mod", 'name = "example/module"')
                    archive.writestr(entry, "unexpected content")
                with self.assertRaises(ValueError):
                    check_archive(archive_path)

    def test_publish_requires_success_marker_regardless_of_exit_code(self):
        archive_dir = self.path / "module" / "_build" / "publish"
        archive_dir.mkdir(parents=True)
        with zipfile.ZipFile(archive_dir / "candidate.zip", "w") as archive:
            archive.writestr("moon.mod", 'name = "example/module"')
        for status, output, expected in [
            (255, "Dry run completed successfully", 0),
            (0, "Dry run completed successfully", 0),
            (0, "No success marker", 1),
            (1, "Registry denied request", 1),
        ]:
            with self.subTest(status=status, output=output):
                result = self.shell(f'''
ROOT="$1" MODULE="$2/module"
source "$ROOT/scripts/registry_release.sh"
moon() {{
  if [[ "$1" == tree ]]; then printf '%s\\n' 'stable dependency tree'; return 0; fi
  if [[ "$1" == package ]]; then return 0; fi
  printf '%s\\n' '{output}'
  return {status}
}}
check_registry_publish
''')
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_dirty_archive_is_rejected_before_publish(self):
        archive_dir = self.path / "module" / "_build" / "publish"
        archive_dir.mkdir(parents=True)
        with zipfile.ZipFile(archive_dir / "candidate.zip", "w") as archive:
            archive.writestr("moon.mod", 'name = "example/module"')
            archive.writestr("_build/native/app.exe", "build output")
        result = self.shell('''
ROOT="$1" MODULE="$2/module" CALLED="$2/publish-called"
source "$ROOT/scripts/registry_release.sh"
moon() {
  if [[ "$1" == publish ]]; then touch "$CALLED"; fi
}
check_registry_publish
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.path / "publish-called").exists())

    def test_publish_success_cannot_hide_dependency_drift(self):
        archive_dir = self.path / "module" / "_build" / "publish"
        archive_dir.mkdir(parents=True)
        with zipfile.ZipFile(archive_dir / "candidate.zip", "w") as archive:
            archive.writestr("moon.mod", 'name = "example/module"')
        result = self.shell('''
ROOT="$1" MODULE="$2/module" CALLED="$2/publish-called"
source "$ROOT/scripts/registry_release.sh"
moon() {
  case "$1" in
    tree) if [[ -f "$CALLED" ]]; then echo changed; else echo original; fi ;;
    package) return 0 ;;
    publish) touch "$CALLED"; echo 'Dry run completed successfully' ;;
  esac
}
check_registry_publish
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dependency selections changed", result.stderr)


if __name__ == "__main__":
    unittest.main()
