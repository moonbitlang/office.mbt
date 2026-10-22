#!/usr/bin/env python3
"""Exercise the real Office PDF CLI on native or Wasm using the same checks.

Usage: python3 office-cli/tests/pdf_cli.py /absolute/path/to/office.exe
       python3 office-cli/tests/pdf_cli.py moonrun -- /absolute/path/to/office.wasm
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "pdflite/fixtures/camlpdf/logo.pdf"
FIXTURES = Path(__file__).resolve().parent / "fixtures"
LAUNCH = sys.argv[1:]
assert LAUNCH, "provide an Office executable or a moonrun command"
checks = 0


def invoke(*args, success=True, pdf=True):
    global checks
    result = subprocess.run(
        [*LAUNCH, *(["pdf"] if pdf else []), *map(str, args)],
        capture_output=True, text=True, timeout=60,
    )
    checks += 1
    assert (result.returncode == 0) == success, (args, result.returncode, result.stdout, result.stderr)
    if success:
        assert not result.stderr, (args, result.stderr)
    else:
        assert not result.stdout, (args, result.stdout)
    return result


def report(*args, success=True, code=None, mode="--json", pdf=True):
    result = invoke(*args, mode, success=success, pdf=pdf)
    text = result.stdout if success else result.stderr
    value = json.loads(text)
    assert value["schema"] == "office.output/1", value
    assert value["success"] == success, value
    if not success:
        if code:
            assert value["error"]["code"] == code, value
        return value
    if pdf:
        assert value["data"]["schema"] == "office.pdf/1", value
    if mode == "--jsonl":
        assert len(text.splitlines()) == 1
    return value["data"]


with tempfile.TemporaryDirectory(prefix="office-pdf-") as work:
    import os
    os.chdir(work)
    help_text = invoke("--help").stdout
    for operation in ("info", "pages", "fonts", "validate", "rewrite", "decrypt", "extract", "merge", "metadata", "bookmarks", "labels"):
        assert operation in help_text
    assert "--overwrite" in invoke("extract", "--help").stdout
    capabilities = report("help", "pdf", pdf=False)
    variants = {item["name"] for item in capabilities["records"][0]["variants"]}
    assert {"info", "merge", "metadata set", "bookmarks import", "labels remove"} <= variants
    assert json.loads(invoke("help", "pdf", "--jsonl", pdf=False).stdout)["name"] == "pdf"
    info = report("info", LOGO)["result"]
    assert (info["version"], info["pages"], info["encrypted"]) == ("1.4", 1, False)
    assert "pages: 1" in invoke("info", LOGO).stdout
    report("info", LOGO, "--detailed")
    report("validate", LOGO)
    assert "valid:" in invoke("validate", LOGO).stdout
    assert len(report("pages", LOGO, mode="--jsonl")["result"]) == 1
    report("fonts", LOGO)
    report("fonts", LOGO, "--missing")
    report("pages", LOGO, "--output", "pages.json")
    assert isinstance(json.loads(Path("pages.json").read_text()), list)
    report("fonts", LOGO, "--output", "fonts.json")
    json.loads(Path("fonts.json").read_text())
    report("rewrite", LOGO, "rewritten.pdf")
    assert report("info", "rewritten.pdf")["result"]["pages"] == 1
    original = Path("rewritten.pdf").read_bytes()
    report("rewrite", LOGO, "rewritten.pdf", success=False, code="office.transaction.output_exists")
    assert Path("rewritten.pdf").read_bytes() == original
    report("rewrite", LOGO, "rewritten.pdf", "--dry-run", success=False, code="office.transaction.output_exists")
    dry = report("rewrite", LOGO, "rewritten.pdf", "--dry-run", "--overwrite")
    assert dry["dry_run"] and not dry["committed"]
    assert Path("rewritten.pdf").read_bytes() == original
    dry = report("rewrite", LOGO, "dry.pdf", "--dry-run")
    assert not dry["committed"] and not Path("dry.pdf").exists()
    report("rewrite", LOGO, "rewritten.pdf", "--overwrite")
    report("rewrite", LOGO, "absent-parent/output.pdf", success=False)
    assert not Path("absent-parent/output.pdf").exists()
    report("extract", LOGO, "extracted.pdf", "--pages", "1,1", "--retain-numbering", "--process-struct-tree")
    assert report("info", "extracted.pdf")["result"]["pages"] == 2
    report("extract", FIXTURES / "two-pages.pdf", "ordered.pdf", "--pages", "2,1,2")
    assert [page["Rotation"] for page in report("pages", "ordered.pdf")["result"]] == [90, 0, 90]
    report("merge", "ordered-merge.pdf", FIXTURES / "two-pages.pdf", LOGO, "--pages", "2,1", "--pages", "1")
    assert [page["Rotation"] for page in report("pages", "ordered-merge.pdf")["result"]] == [90, 0, 0]
    report("merge", "merged.pdf", "extracted.pdf", LOGO, "--pages", "2,1,2", "--pages", "all",
           "--retain-numbering", "--remove-duplicate-fonts", "--add-toplevel-document",
           "--drop-bookmarks", "--drop-optional-content", "--drop-acroforms", "--drop-named-destinations",
           "--drop-name-dictionary", "--drop-structure-tree", "--drop-info", "--drop-catalog-entries")
    assert report("info", "merged.pdf")["result"]["pages"] == 4
    for spec in ("", "0", "2", "odd even", "even"):
        report("extract", LOGO, "invalid.pdf", "--pages", spec, success=False, code="office.invalid_arguments")
        assert not Path("invalid.pdf").exists()
    report("merge", "invalid.pdf", LOGO, LOGO, "--pages", "1", success=False, code="office.invalid_arguments")
    report("merge", "invalid.pdf", LOGO, success=False, code="office.invalid_arguments")
    report("--bad", success=False, code="office.invalid_arguments")
    report("info", "missing.pdf", success=False, code="office.pdf.failed")
    report("merge", "invalid.pdf", LOGO, "missing.pdf", success=False, code="office.pdf.failed")
    Path("bad.pdf").write_bytes(b"not a pdf")
    report("info", "bad.pdf", success=False, code="office.pdf.failed")
    report("info", LOGO, "--jsonl", success=False, code="office.output_mode_conflict")
    report("metadata", "set", LOGO, "metadata.pdf", "--title", "中文标题", "--author", "Author", "--xmp-also")
    assert report("metadata", "get", "metadata.pdf")["result"]["title"] == "中文标题"
    report("metadata", "get", "metadata.pdf", "--output", "info.json")
    assert json.loads(Path("info.json").read_text())["author"] == "Author"
    report("metadata", "export", "metadata.pdf", "--output", "metadata.xml")
    assert Path("metadata.xml").read_bytes()
    report("metadata", "import", LOGO, "imported.pdf", "metadata.xml")
    report("metadata", "remove", "metadata.pdf", "removed.pdf", "--scope", "all")
    assert report("metadata", "get", "removed.pdf")["result"]["title"] == ""
    report("metadata", "set", LOGO, "invalid.pdf", success=False, code="office.invalid_arguments")
    report("metadata", "remove", LOGO, "invalid.pdf", "--scope", "bogus", success=False, code="office.invalid_arguments")
    report("metadata", "export", LOGO, success=False, code="office.pdf.failed")
    Path("invalid.xml").write_text("<broken>")
    report("metadata", "import", LOGO, "invalid.pdf", "invalid.xml", success=False)
    assert not Path("invalid.pdf").exists()
    # Raw export files must remain directly importable, not Office envelopes.
    report("bookmarks", "export", LOGO, "--output", "bookmarks.json")
    assert isinstance(json.loads(Path("bookmarks.json").read_text()), list)
    report("bookmarks", "import", LOGO, "bookmarks.pdf", "bookmarks.json")
    report("bookmarks", "remove", "bookmarks.pdf", "no-bookmarks.pdf")
    report("bookmarks", "export", LOGO, "--text", "--output", "bookmarks.txt")
    report("bookmarks", "import", LOGO, "text-bookmarks.pdf", "bookmarks.txt", "--text")
    Path("labels.json").write_text(json.dumps([{"labelstyle": "LowercaseRoman", "labelprefix": "A", "startpage": 1, "startvalue": 2}]))
    report("labels", "import", LOGO, "labels.pdf", "labels.json")
    labels = report("labels", "export", "labels.pdf", "--output", "labels-export.json")["result"]
    assert labels[0]["startvalue"] == 2
    report("labels", "import", LOGO, "labels-roundtrip.pdf", "labels-export.json")
    report("labels", "remove", "labels.pdf", "no-labels.pdf")
    assert report("labels", "export", "no-labels.pdf")["result"] == []
    # Export arbitrary XMP bytes exactly, including XML encoded as UTF-16.
    xml_bytes = '<x:xmpmeta xmlns:x="adobe:ns:meta/"/>'.encode("utf-16")
    objects = [b"<< /Type /Catalog /Pages 2 0 R /Metadata 4 0 R >>",
               b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
               b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
               b"<< /Type /Metadata /Subtype /XML /Length " + str(len(xml_bytes)).encode() + b" >>\nstream\n" + xml_bytes + b"\nendstream"]
    pdf_bytes = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for number, body in enumerate(objects, 1):
        offsets.append(len(pdf_bytes))
        pdf_bytes.extend(f"{number} 0 obj\n".encode() + body + b"\nendobj\n")
    xref = len(pdf_bytes)
    pdf_bytes.extend(b"xref\n0 5\n0000000000 65535 f \n")
    for offset in offsets[1:]:
        pdf_bytes.extend(f"{offset:010} 00000 n \n".encode())
    pdf_bytes.extend(f"trailer\n<< /Root 1 0 R /Size 5 >>\nstartxref\n{xref}\n%%EOF\n".encode())
    Path("utf16.pdf").write_bytes(pdf_bytes)
    exported = report("metadata", "export", "utf16.pdf", "--output", "utf16.xml")["result"]
    import base64
    assert exported["encoding"] == "base64"
    assert base64.b64decode(exported["content"]) == xml_bytes == Path("utf16.xml").read_bytes()
    raw = subprocess.run([*LAUNCH, "pdf", "metadata", "export", "utf16.pdf"], capture_output=True, timeout=60)
    checks += 1
    assert raw.returncode == 0 and raw.stdout == xml_bytes and not raw.stderr
    # Publication rules apply equally to reports, XML and PDF candidates.
    for args, path in [
        (("metadata", "export", "metadata.pdf", "--output", "metadata.xml"), "metadata.xml"),
        (("bookmarks", "export", LOGO, "--output", "bookmarks.json"), "bookmarks.json"),
        (("labels", "export", "labels.pdf", "--output", "labels-export.json"), "labels-export.json"),
        (("pages", LOGO, "--output", "pages.json"), "pages.json"),
    ]:
        before = Path(path).read_bytes()
        report(*args, success=False, code="office.transaction.output_exists")
        report(*args, "--dry-run", "--overwrite")
        assert Path(path).read_bytes() == before
        report(*args, "--overwrite")
    report("metadata", "export", "metadata.pdf", "--output", "dry.xml", "--dry-run")
    assert not Path("dry.xml").exists()
    locked = FIXTURES / "password.pdf"
    assert report("info", locked, "--password", "user-secret")["result"]["encrypted"] is False
    report("--password", "user-secret", "info", locked)
    Path("password.bin").write_bytes(b"user-secret")
    report("decrypt", locked, "unlocked.pdf", "--password-file", "password.bin")
    assert report("info", "unlocked.pdf")["result"]["encrypted"] is False
    report("decrypt", locked, "owner-unlocked.pdf", "--owner-password", "owner-secret")
    Path("owner.bin").write_bytes(b"owner-secret")
    report("info", locked, "--owner-password-file", "owner.bin")
    report("decrypt", FIXTURES / "empty-password.pdf", "empty-unlocked.pdf")
    report("decrypt", locked, "invalid.pdf", "--password", "wrong", success=False, code="office.pdf.failed")
    Path("password.bin").write_bytes(b"user-secret\n")
    report("decrypt", locked, "invalid.pdf", "--password-file", "password.bin", success=False, code="office.pdf.failed")
    report("info", locked, "--password", "user-secret", "--password-file", "password.bin", success=False, code="office.invalid_arguments")
    assert not Path("invalid.pdf").exists()
    assert not list(Path(".").glob(".office-output-tmp-*"))

print(f"office pdf: {checks} CLI checks passed")
