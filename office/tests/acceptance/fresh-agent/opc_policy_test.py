#!/usr/bin/env python3
"""Contract tests for the bounded OPC package validator."""

import os
import subprocess
import sys
import tempfile
import zipfile


CONTENT_TYPES = "http://schemas.openxmlformats.org/package/2006/content-types"
RELATIONSHIPS = "http://schemas.openxmlformats.org/package/2006/relationships"
OFFICE_DOCUMENT = (
    "http://schemas.openxmlformats.org/officeDocument/2006/"
    "relationships/officeDocument"
)
RELS_CONTENT_TYPE = "application/vnd.openxmlformats-package.relationships+xml"
XLSX_CONTENT_TYPE = (
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"
)
DOCX_CONTENT_TYPE = (
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"
)


def content_types(main_part, main_type, extras=(), include_xml_default=False):
    defaults = [
        '<Default Extension="rels" ContentType="%s"/>' % RELS_CONTENT_TYPE
    ]
    if include_xml_default:
        defaults.append('<Default Extension="xml" ContentType="application/xml"/>')
    overrides = [
        '<Override PartName="/%s" ContentType="%s"/>' % (main_part, main_type)
    ]
    overrides.extend(extras)
    return (
        '<?xml version="1.0"?><Types xmlns="%s">%s%s</Types>'
        % (CONTENT_TYPES, "".join(defaults), "".join(overrides))
    ).encode()


def root_relationship(main_part):
    return (
        '<?xml version="1.0"?><Relationships xmlns="%s">'
        '<Relationship Id="rId1" Type="%s" Target="%s"/>'
        "</Relationships>"
        % (RELATIONSHIPS, OFFICE_DOCUMENT, main_part)
    ).encode()


def fixture(format_name, extra_parts=None, include_xml_default=False):
    if format_name == "xlsx":
        main_part = "xl/workbook.xml"
        main_type = XLSX_CONTENT_TYPE
        main_xml = (
            '<workbook xmlns="http://schemas.openxmlformats.org/'
            'spreadsheetml/2006/main"/>'
        ).encode()
    else:
        main_part = "word/document.xml"
        main_type = DOCX_CONTENT_TYPE
        main_xml = (
            '<w:document xmlns:w="http://schemas.openxmlformats.org/'
            'wordprocessingml/2006/main"><w:body/></w:document>'
        ).encode()
    parts = {
        "[Content_Types].xml": content_types(
            main_part,
            main_type,
            include_xml_default=include_xml_default,
        ),
        "_rels/.rels": root_relationship(main_part),
        main_part: main_xml,
    }
    if extra_parts:
        parts.update(extra_parts)
    return parts


def write_package(path, parts, compression=zipfile.ZIP_DEFLATED):
    with zipfile.ZipFile(path, "w", compression=compression) as archive:
        for name, payload in parts.items():
            archive.writestr(name, payload)


def invoke(policy, package, format_name):
    return subprocess.run(
        [sys.executable, "-I", policy, package, format_name, "10"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env={"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"},
    )


def expect(policy, root, label, format_name, parts, accepted, pattern=None, compression=None):
    package = os.path.join(root, "%s.%s" % (label, format_name))
    write_package(
        package,
        parts,
        zipfile.ZIP_DEFLATED if compression is None else compression,
    )
    result = invoke(policy, package, format_name)
    if accepted and result.returncode != 0:
        raise AssertionError("%s was rejected: %s" % (label, result.stderr.decode()))
    if not accepted and result.returncode == 0:
        raise AssertionError("%s was unexpectedly accepted" % label)
    if pattern is not None and pattern.encode() not in result.stderr:
        raise AssertionError("%s omitted diagnostic %r: %r" % (label, pattern, result.stderr))
    return package


def main(argv):
    if len(argv) != 2:
        print("usage: opc_policy_test.py OPC_POLICY", file=sys.stderr)
        return 2
    policy = os.path.abspath(argv[1])
    with tempfile.TemporaryDirectory(prefix="opc-policy-test.") as root:
        expect(policy, root, "valid-xlsx", "xlsx", fixture("xlsx"), True)
        expect(policy, root, "valid-docx", "docx", fixture("docx"), True)

        encoded_types = fixture("xlsx")
        encoded_types["[Content%5FTypes].xml"] = encoded_types.pop(
            "[Content_Types].xml"
        )
        expect(
            policy,
            root,
            "percent-encoded-content-types",
            "xlsx",
            encoded_types,
            False,
            "non-canonical percent escape",
        )

        encoded_main = fixture("xlsx")
        encoded_main["xl/workbook%2Exml"] = encoded_main.pop("xl/workbook.xml")
        expect(
            policy,
            root,
            "percent-encoded-main-part",
            "xlsx",
            encoded_main,
            False,
            "non-canonical percent escape",
        )

        overridden_rels = fixture("xlsx")
        overridden_rels["[Content_Types].xml"] = content_types(
            "xl/workbook.xml",
            XLSX_CONTENT_TYPE,
            extras=(
                '<Override PartName="/_rels/.rels" ContentType="text/plain"/>',
            ),
        )
        expect(
            policy,
            root,
            "relationships-override",
            "xlsx",
            overridden_rels,
            False,
            "wrong effective content type",
        )

        lzma_parts = fixture("xlsx")
        lzma_parts["payload.bin"] = b"\0" * (1024 * 1024)
        expect(
            policy,
            root,
            "lzma",
            "xlsx",
            lzma_parts,
            False,
            "unsupported compression method",
            zipfile.ZIP_LZMA,
        )

        untyped = fixture("xlsx")
        untyped["mystery.bin"] = b"payload"
        expect(
            policy,
            root,
            "untyped",
            "xlsx",
            untyped,
            False,
            "no complete content-type declaration",
        )

        malformed_rels = fixture("xlsx")
        malformed_rels["xl/_rels/workbook.xml.rels"] = b"<not-relationships/>"
        expect(
            policy,
            root,
            "malformed-aux-rels",
            "xlsx",
            malformed_rels,
            False,
            "unexpected OPC relationships root",
        )

        dtd_part = fixture("xlsx", include_xml_default=True)
        dtd_part["customXml/item1.xml"] = (
            b'<!DOCTYPE x [<!ENTITY e "payload">]><x>&e;</x>'
        )
        expect(
            policy,
            root,
            "aux-dtd",
            "xlsx",
            dtd_part,
            False,
            "DTD or entity declaration",
        )

        missing_target = fixture("xlsx")
        missing_target["xl/_rels/workbook.xml.rels"] = (
            '<?xml version="1.0"?><Relationships xmlns="%s">'
            '<Relationship Id="rId2" Type="urn:test" Target="missing.xml"/>'
            "</Relationships>" % RELATIONSHIPS
        ).encode()
        expect(
            policy,
            root,
            "missing-target",
            "xlsx",
            missing_target,
            False,
            "targets a missing part",
        )

        nul_parts = fixture("xlsx", include_xml_default=True)
        nul_parts["extra.xml"] = b"<extra/>"
        nul_package = expect(
            policy,
            root,
            "nul-source",
            "xlsx",
            nul_parts,
            True,
        )
        with open(nul_package, "rb") as stream:
            payload = stream.read()
        if payload.count(b"extra.xml") < 2:
            raise AssertionError("NUL fixture did not expose both ZIP filenames")
        payload = payload.replace(b"extra.xml", b"evil\x00.xml")
        nul_package = os.path.join(root, "raw-nul.xlsx")
        with open(nul_package, "wb") as stream:
            stream.write(payload)
        result = invoke(policy, nul_package, "xlsx")
        if result.returncode == 0 or b"raw NUL" not in result.stderr:
            raise AssertionError("raw NUL ZIP filename was not rejected: %r" % result.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
