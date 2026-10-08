"""Exercise cold/warm validator builds under captured pipes without .NET."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
FAKE_DOTNET = '''
import pathlib, subprocess, sys
root = pathlib.Path.cwd()
if sys.argv[1] == "--list-runtimes":
    print("Microsoft.NETCore.App 8.0.0 [fake]")
elif sys.argv[1] == "build":
    with (root / "builds").open("a") as log:
        log.write("build\\n")
    if "-p:UseSharedCompilation=false" not in sys.argv or "--disable-build-servers" not in sys.argv:
        # Model Roslyn retaining the parent's captured stderr after build exits.
        subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
    dll = root / "tools/openxml-validator/bin/Debug/net8.0/OpenXmlValidator.dll"
    dll.parent.mkdir(parents=True, exist_ok=True)
    dll.touch()
else:
    print("validated")
'''


class ValidatorBuildTest(unittest.TestCase):
    def test_cold_and_warm_captured_validation(self):
        for kind in ("docx", "xlsx", "pptx"):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "scripts").mkdir()
                script = root / f"scripts/validate_{kind}.sh"
                shutil.copy(ROOT / f"scripts/validate_{kind}.sh", script)
                ensure = root / "scripts/ensure_dotnet.sh"
                ensure.write_text("#!/bin/sh\nexit 0\n")
                ensure.chmod(0o755)
                dotnet = root / ".tools/dotnet/dotnet"
                dotnet.parent.mkdir(parents=True)
                dotnet.write_text(f"#!{sys.executable}\n" + FAKE_DOTNET)
                dotnet.chmod(0o755)
                project = root / "tools/openxml-validator"
                project.mkdir(parents=True)
                (project / "OpenXmlValidator.csproj").touch()
                (project / "Program.cs").touch()
                fixture = root / f"fixture.{kind}"
                with zipfile.ZipFile(fixture, "w") as archive:
                    for name in ("[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels"):
                        archive.writestr(name, "<root/>")
                env = dict(os.environ, PATH=str(dotnet.parent) + os.pathsep + os.environ["PATH"])
                for phase in ("cold", "warm"):
                    proc = subprocess.Popen(["bash", str(script), str(fixture)], cwd=root,
                                            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                            start_new_session=True)
                    try:
                        stdout, stderr = proc.communicate(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(proc.pid, signal.SIGKILL)
                        proc.communicate()
                        self.fail(f"{kind} {phase}: build child retained captured pipes")
                    self.assertEqual(proc.returncode, 0, stderr.decode())
                    self.assertIn(b"validated", stdout)
                    self.assertFalse((root / ".tools/openxml-validator/.lock").exists())
                self.assertEqual((root / "builds").read_text(), "build\n")


if __name__ == "__main__":
    unittest.main()
